NETWORK EXTENSION MEMORY STRESS TEST

iOS application for testing and monitoring memory consumption of Network 
Extension with 50 MB limit.

AUTHOR

This test application was created with the assistance of AI (Neural Network / 
Large Language Model) as part of a research project investigating iOS Network 
Extension memory limits and behavior under pressure.

PURPOSE

Investigate and visualize how iOS limits Network Extension memory, including:
- Track system memory pressure warnings (WARNING/CRITICAL)
- Test extension behavior when approaching 50 MB limit
- Observe automatic memory cleanup
- Communicate with extension via XPC messages

FEATURES

VPN Management:
- Create VPN - programmatically create VPN configuration
- Connect VPN - start tunnel connection
- Delete VPN - remove existing configuration

Extension Monitoring:
- Query Memory - manual request for current usage
- Auto Poll (5s) - automatic monitoring every 5 seconds
- Visual Indicator - display extension memory in UI

Stress Testing:
- FF Alloc - allocate memory with 0xFF pattern
- Real Image - allocate real rendered images (gradients + shapes)
- Multiple Images - batch image creation
- Stress Alloc (FF) - cyclic allocation 1-50 MB
- Stress Extension - automatic allocation until limit hit

REQUIREMENTS

- Xcode 14+
- iOS 15+
- Apple Developer Program (required for Network Extension)

INSTALLATION

1. Clone repository:
   git clone https://github.com/yourusername/NetwExtMemoryTest.git
   cd NetwExtMemoryTest

2. Configure Bundle Identifiers:
   - Open NetwExtMemoryTest.xcodeproj
   - For both targets replace com.yourcompany with your Bundle ID
   - Extension identifier must be a sub-identifier of the app:
     App: com.yourcompany.NetwExtMemoryTest
     Extension: com.yourcompany.NetwExtMemoryTest.PacketTunnelOBJ-C

3. Configure Entitlements:
   - Add Network Extensions capability for both targets
   - Enable Packet Tunnel Provider

4. Code Signing:
   - Select your developer team in Signing & Capabilities

USAGE

1. Tap "Create VPN" - creates VPN configuration
2. Tap "Connect VPN" - starts tunnel connection
3. Tap "Query Memory" - check current extension memory usage
4. Tap "Stress Extension" - run stress test until memory limit

EXPECTED BEHAVIOR

Memory          Event               System Action
-------------------------------------------------------------------------------
< 40 MB         Normal              Normal operation
40-45 MB        WARNING             DISPATCH_MEMORYPRESSURE_WARNING
45-48 MB        Warning             Extension receives notification
48-50 MB        CRITICAL            DISPATCH_MEMORYPRESSURE_CRITICAL
>= 50 MB        KILL                Jetsam terminates process

TROUBLESHOOTING

Error: NEVPNErrorDomain error 2
Solution: Call loadFromPreferencesWithCompletionHandler twice

Error: NEAgentErrorDomain Code=2
Solution: Check Bundle Identifier hierarchy and entitlements

Error: <private> in logs
Solution: Use os_log with %{public}@ or check Xcode scheme

Extension not loading
Solution: Verify extension is in PlugIns folder of built .app

PROJECT STRUCTURE

NetwExtMemoryTest/
├── NetwExtMemoryTest/           # Main app
│   ├── ViewController.m         # UI and VPN management
│   ├── AppDelegate.m
│   └── SceneDelegate.m
├── PacketTunnelOBJ-C/           # Network Extension
│   ├── PacketTunnelProvider.m   # Tunnel logic + memory monitor
│   └── PacketTunnelOBJ_C.entitlements
└── Shared/
    ├── MemoryMonitor.h          # Shared memory monitoring
    └── MemoryMonitor.m          # FF allocation + real images

LOG INTERPRETATION

[EXTENSION] [FF] Allocated 5 MB. Total: 1 blocks. Memory: 12.34 MB
[EXTENSION] WARNING - Memory usage: 40.12 MB
[EXTENSION] Cleaning up extension memory...
[EXTENSION] CRITICAL - Emergency cleanup!

AI DISCLAIMER

This software was generated with the assistance of an artificial intelligence 
(AI) system. While the code has been reviewed and tested, users should exercise 
appropriate caution when deploying in production environments.

NOTES

- Network Extensions require paid Apple Developer Program membership
- Memory limit is 50 MB on iOS 15+ (was 15 MB on older versions)
- Extension runs in a separate process with strict sandbox
- Use DispatchSource.makeMemoryPressureSource for pre-kill notifications

LICENSE

MIT License
