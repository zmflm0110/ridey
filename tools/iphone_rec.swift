// 케이블로 연결된 아이폰 화면을 맥에서 녹화한다(QuickTime 과 같은 방식, 폰에는 녹화 표시 없음).
// 빌드: swiftc -O tools/iphone_rec.swift -o /tmp/iphone_rec
// 사용: iphone_rec 출력.mov   — 멈추려면 '출력.mov.stop' 파일을 만들거나 Ctrl-C.
import AVFoundation
import CoreMediaIO
import Foundation

var prop = CMIOObjectPropertyAddress(
  mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
  mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
  mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
var allow: UInt32 = 1
CMIOObjectSetPropertyData(
  CMIOObjectID(kCMIOObjectSystemObject), &prop, 0, nil, UInt32(MemoryLayout<UInt32>.size), &allow)

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let stopPath = out.path + ".stop"
try? FileManager.default.removeItem(at: out)
try? FileManager.default.removeItem(atPath: stopPath)

var device: AVCaptureDevice?
for _ in 0..<40 {
  RunLoop.current.run(until: Date().addingTimeInterval(0.5))
  device = AVCaptureDevice.DiscoverySession(
    deviceTypes: [.external], mediaType: .muxed, position: .unspecified
  ).devices.first
  if device != nil { break }
}
guard let phone = device else {
  print("NO_DEVICE")
  exit(2)
}
print("DEVICE", phone.localizedName)

final class Delegate: NSObject, AVCaptureFileOutputRecordingDelegate {
  func fileOutput(_ o: AVCaptureFileOutput, didStartRecordingTo u: URL, from c: [AVCaptureConnection]) {
    print("RECORDING")
    fflush(stdout)
  }
  func fileOutput(
    _ o: AVCaptureFileOutput, didFinishRecordingTo u: URL, from c: [AVCaptureConnection], error: Error?
  ) {
    print("FINISHED", error?.localizedDescription ?? "ok")
    fflush(stdout)
    exit(0)
  }
}
let session = AVCaptureSession()
session.addInput(try AVCaptureDeviceInput(device: phone))
let output = AVCaptureMovieFileOutput()
session.addOutput(output)
session.startRunning()
let delegate = Delegate()
RunLoop.current.run(until: Date().addingTimeInterval(1.0))
output.startRecording(to: out, recordingDelegate: delegate)
signal(SIGINT, SIG_IGN)
let sig = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sig.setEventHandler { output.stopRecording() }
sig.resume()
Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
  if FileManager.default.fileExists(atPath: stopPath) {
    try? FileManager.default.removeItem(atPath: stopPath)
    output.stopRecording()
  }
}
RunLoop.main.run()
