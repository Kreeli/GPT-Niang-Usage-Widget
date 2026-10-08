// One persistent output device and a dedicated PCM mixer. UI calls only update short in-memory records.
using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;
using System.Diagnostics;
public sealed class NiangClickAudio : IDisposable {
 [StructLayout(LayoutKind.Sequential,Pack=2)] struct WaveFormat { public ushort tag,channels; public uint rate,bytesPerSecond; public ushort alignment,bits,extra; }
 [StructLayout(LayoutKind.Sequential)] struct WaveHeader { public IntPtr data; public uint length,recorded; public UIntPtr user; public uint flags,loops; public IntPtr next; public UIntPtr reserved; }
 [DllImport("winmm.dll")] static extern uint waveOutOpen(out IntPtr handle,uint device,ref WaveFormat format,IntPtr callback,IntPtr instance,uint flags);
 [DllImport("winmm.dll")] static extern uint waveOutPrepareHeader(IntPtr handle,IntPtr header,uint size);
 [DllImport("winmm.dll")] static extern uint waveOutUnprepareHeader(IntPtr handle,IntPtr header,uint size);
 [DllImport("winmm.dll")] static extern uint waveOutWrite(IntPtr handle,IntPtr header,uint size);
 [DllImport("winmm.dll")] static extern uint waveOutReset(IntPtr handle);
 [DllImport("winmm.dll")] static extern uint waveOutClose(IntPtr handle);
 static readonly uint HeaderSize=(uint)Marshal.SizeOf(typeof(WaveHeader));
 static void Check(uint value) { if(value!=0)throw new InvalidOperationException("waveOut error "+value); }
 sealed class Clip {
  public WaveFormat Format; public short[] Samples; public int Frames {get{return Samples.Length/Format.channels;}}
  public static Clip Load(string path) {
   using(var r=new BinaryReader(File.OpenRead(path))) {
    if(new string(r.ReadChars(4))!="RIFF")throw new InvalidDataException("Expected RIFF");r.ReadUInt32();
    if(new string(r.ReadChars(4))!="WAVE")throw new InvalidDataException("Expected WAVE");
    var clip=new Clip();bool format=false;byte[] data=null;
    while(r.BaseStream.Position+8<=r.BaseStream.Length) {
     string id=new string(r.ReadChars(4));uint size=r.ReadUInt32();long end=r.BaseStream.Position+size+(size%2);
     if(end>r.BaseStream.Length)throw new InvalidDataException("Truncated WAV");
     if(id=="fmt ") {
      if(size<16)throw new InvalidDataException("Invalid format");
      clip.Format.tag=r.ReadUInt16();clip.Format.channels=r.ReadUInt16();clip.Format.rate=r.ReadUInt32();
      clip.Format.bytesPerSecond=r.ReadUInt32();clip.Format.alignment=r.ReadUInt16();clip.Format.bits=r.ReadUInt16();format=true;
     }else if(id=="data")data=r.ReadBytes(checked((int)size));
     r.BaseStream.Position=end;
    }
    if(!format || clip.Format.tag!=1 || clip.Format.bits!=16 || clip.Format.channels<1 || clip.Format.channels>2 || clip.Format.rate==0 || clip.Format.alignment!=clip.Format.channels*2 || clip.Format.bytesPerSecond!=clip.Format.rate*clip.Format.alignment || data==null || data.Length==0 || data.Length%clip.Format.alignment!=0)throw new InvalidDataException("Expected 16-bit PCM WAV");
    clip.Samples=new short[data.Length/2];Buffer.BlockCopy(data,0,clip.Samples,0,data.Length);return clip;
   }
  }
 }
 sealed class OutputBuffer {
  public IntPtr Header,Data;public byte[] Bytes;public int[] Mix;public long EndFrame;
  public OutputBuffer(IntPtr handle,int samples) {
   Bytes=new byte[samples*2];Mix=new int[samples];Data=Marshal.AllocHGlobal(Bytes.Length);Header=Marshal.AllocHGlobal((int)HeaderSize);
   Marshal.StructureToPtr(new WaveHeader{data=Data,length=(uint)Bytes.Length},Header,false);Check(waveOutPrepareHeader(handle,Header,HeaderSize));
  }
  public bool Done {get{return (((WaveHeader)Marshal.PtrToStructure(Header,typeof(WaveHeader))).flags&1)!=0;}}
  public void Submit(IntPtr handle) {Marshal.Copy(Bytes,0,Data,Bytes.Length);Check(waveOutWrite(handle,Header,HeaderSize));}
  public void Free(IntPtr handle) {
   uint result=waveOutUnprepareHeader(handle,Header,HeaderSize);
   for(int i=0;result==33 && i<100;i++){Thread.Sleep(5);result=waveOutUnprepareHeader(handle,Header,HeaderSize);}
   Check(result);Marshal.FreeHGlobal(Header);Marshal.FreeHGlobal(Data);Header=Data=IntPtr.Zero;
  }
 }
 sealed class Voice {public long Id,Start,Release=Int64.MaxValue,Accepted;public bool Mixed,PressReported,ReleaseReported;}
 readonly object gate=new object();readonly Clip press,release;readonly List<Voice> voices=new List<Voice>();
 readonly AutoResetEvent wake=new AutoResetEvent(false);readonly Thread worker;
 readonly int framesPerBuffer;long nextFrame,playedFrame,sequence,active,epoch;
 bool disposed,ready;double volume=0.9;int pressStarted,pressCompleted,releaseStarted,releaseCompleted,rejected,failed,cancelled,opens,dropped;
 string lastError;
 public bool Ready {get{lock(gate)return ready;}}
 public double Volume {get{lock(gate)return volume;}set{lock(gate)volume=Double.IsNaN(value)?0.9:Math.Max(0,Math.Min(1,value));}}
 public int ActiveVoices {get{lock(gate)return voices.Count;}}
 public int PressStarted {get{lock(gate)return pressStarted;}} public int PressCompleted {get{lock(gate)return pressCompleted;}}
 public int ReleaseStarted {get{lock(gate)return releaseStarted;}} public int ReleaseCompleted {get{lock(gate)return releaseCompleted;}}
 public int Rejected {get{lock(gate)return rejected;}} public int Failed {get{lock(gate)return failed;}}
 public int Cancelled {get{lock(gate)return cancelled;}} public int DroppedStale {get{lock(gate)return dropped;}}
 public int DeviceOpenCount {get{lock(gate)return opens;}} public string LastError {get{lock(gate)return lastError;}}
 public double PressSeconds {get{return (double)press.Frames/press.Format.rate;}}
 public NiangClickAudio(string pressPath,string releasePath) {
  press=Clip.Load(pressPath);release=Clip.Load(releasePath);
  if(press.Format.rate!=release.Format.rate || press.Format.channels!=release.Format.channels)throw new InvalidDataException("Click formats must match");
  framesPerBuffer=Math.Max(1,(int)press.Format.rate/100);
  worker=new Thread(Run);worker.IsBackground=true;worker.Name="Niang PCM mixer";worker.Start();
 }
 public void Press() {
  lock(gate) {
   if(disposed || volume<=0)return;
   if(!ready || voices.Count>=32){rejected++;active=0;return;}
   if(active!=0)ReleaseLocked();
   var v=new Voice{Id=++sequence,Start=nextFrame,Accepted=Stopwatch.GetTimestamp()};voices.Add(v);active=v.Id;pressStarted++;
  }
 }
 void ReleaseLocked() {foreach(var v in voices)if(v.Id==active){v.Release=Math.Max(nextFrame,v.Start+press.Frames);break;}active=0;}
 public void Release() {lock(gate){if(!disposed)ReleaseLocked();}}
 public void Pump() {} // Compatibility: playback never depends on the WPF dispatcher.
 public void Stop() {lock(gate){cancelled+=voices.Count;voices.Clear();active=0;epoch++;}wake.Set();}
 public void Dispose() {lock(gate){if(disposed)return;disposed=true;ready=false;cancelled+=voices.Count;voices.Clear();active=0;}wake.Set();}
 public bool WaitForExit(int milliseconds) {return worker.Join(milliseconds);}
 void UpdatePlayed(long frame) {
  lock(gate) {
   playedFrame=Math.Max(playedFrame,frame);
   for(int i=voices.Count-1;i>=0;i--) {
    var v=voices[i];if(!v.PressReported && playedFrame>=v.Start+press.Frames){v.PressReported=true;pressCompleted++;}
    if(v.Release!=Int64.MaxValue && playedFrame>v.Release) {
     if(!v.ReleaseReported){v.ReleaseReported=true;releaseStarted++;}
     if(playedFrame>=v.Release+release.Frames){releaseCompleted++;voices.RemoveAt(i);}
    }
   }
  }
 }
 void AddClip(OutputBuffer buffer,Clip clip,long clipStart,long bufferStart) {
  long first=Math.Max(bufferStart,clipStart),last=Math.Min(bufferStart+framesPerBuffer,clipStart+clip.Frames);
  if(last<=first)return;
  int from=checked((int)(first-clipStart))*press.Format.channels,to=checked((int)(first-bufferStart))*press.Format.channels;
  int count=checked((int)(last-first))*press.Format.channels;
  for(int i=0;i<count;i++)buffer.Mix[to+i]+=clip.Samples[from+i];
 }
 void Fill(OutputBuffer buffer) {
  Array.Clear(buffer.Mix,0,buffer.Mix.Length);double gain;
  lock(gate) {
   long now=Stopwatch.GetTimestamp(),start=nextFrame;
   for(int i=voices.Count-1;i>=0;i--) {
    var v=voices[i];
    if(!v.Mixed && (now-v.Accepted)*1000.0/Stopwatch.Frequency>120){dropped++;voices.RemoveAt(i);if(active==v.Id)active=0;continue;}
    AddClip(buffer,press,v.Start,start);if(v.Release!=Int64.MaxValue)AddClip(buffer,release,v.Release,start);
    if(start+framesPerBuffer>v.Start)v.Mixed=true;
   }
   gain=volume;nextFrame+=framesPerBuffer;buffer.EndFrame=nextFrame;
  }
  for(int i=0;i<buffer.Mix.Length;i++) {
   short value=(short)Math.Max(Int16.MinValue,Math.Min(Int16.MaxValue,Math.Round(buffer.Mix[i]*gain)));
   buffer.Bytes[2*i]=unchecked((byte)value);buffer.Bytes[2*i+1]=unchecked((byte)(value>>8));
  }
 }
 void Run() {
  IntPtr handle=IntPtr.Zero;var buffers=new List<OutputBuffer>();long observedEpoch=0;
  try {
   var format=press.Format;
   Check(waveOutOpen(out handle,UInt32.MaxValue,ref format,wake.SafeWaitHandle.DangerousGetHandle(),IntPtr.Zero,0x50000));
   lock(gate)opens++;
   for(int i=0;i<4;i++){var b=new OutputBuffer(handle,framesPerBuffer*format.channels);buffers.Add(b);Fill(b);b.Submit(handle);}
   lock(gate)ready=true;
   while(true) {
    bool stop;long currentEpoch;lock(gate){stop=disposed;currentEpoch=epoch;}
    if(stop)break;
    if(currentEpoch!=observedEpoch) {
     Check(waveOutReset(handle));lock(gate)playedFrame=nextFrame;observedEpoch=currentEpoch;
     foreach(var b in buffers){Fill(b);b.Submit(handle);}
    }else {
     // Consume every completed buffer before refilling in the original queue order.
     var done=new List<OutputBuffer>();foreach(var b in buffers)if(b.Done)done.Add(b);
     done.Sort((a,b)=>a.EndFrame.CompareTo(b.EndFrame));
     foreach(var b in done)UpdatePlayed(b.EndFrame);
     foreach(var b in done){Fill(b);b.Submit(handle);}
    }
    wake.WaitOne(10);
   }
  }catch(Exception e){lock(gate){failed++;lastError=e.Message;ready=false;}}
  finally {
   if(handle!=IntPtr.Zero) {
    waveOutReset(handle);
    foreach(var b in buffers){try{b.Free(handle);}catch(Exception e){lock(gate){failed++;lastError=e.Message;}}}
    waveOutClose(handle);
   }
   lock(gate)ready=false;
  }
 }
}