#import <Cocoa/Cocoa.h>
#import <mach/mach.h>

@interface RingView : NSView
@property double cpu;
@property double memory;
@property (copy) void (^hoverChanged)(BOOL inside);
@property NSPoint dragStart;
@property NSPoint windowStart;
@property BOOL didDrag;
@property double backgroundShade;
@end

@implementation RingView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas) [self removeTrackingArea:area];
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways owner:self userInfo:nil];
    [self addTrackingArea:area];
}
- (void)mouseEntered:(NSEvent *)event { if (self.hoverChanged) self.hoverChanged(YES); }
- (void)mouseExited:(NSEvent *)event { if (self.hoverChanged) self.hoverChanged(NO); }
- (NSColor *)colorForValue:(double)value {
    if (value < .60) return NSColor.systemGreenColor;
    if (value < .82) return NSColor.systemOrangeColor;
    return NSColor.systemRedColor;
}
- (void)drawRect:(NSRect)dirtyRect {
    NSPoint center = NSMakePoint(NSMidX(self.bounds), NSMidY(self.bounds));
    NSArray *values = @[@(self.cpu), @(self.memory)];
    NSArray *radii = @[@18, @12];
    NSArray *widths = @[@5, @4];
    for (NSInteger i = 0; i < 2; i++) {
        CGFloat radius = [radii[i] doubleValue], width = [widths[i] doubleValue];
        NSBezierPath *track = [NSBezierPath bezierPath];
        [track appendBezierPathWithArcWithCenter:center radius:radius startAngle:0 endAngle:360];
        track.lineWidth = width; track.lineCapStyle = NSLineCapStyleRound;
        [[NSColor.secondaryLabelColor colorWithAlphaComponent:.18] setStroke]; [track stroke];

        double value = [values[i] doubleValue];
        NSBezierPath *arc = [NSBezierPath bezierPath];
        [arc appendBezierPathWithArcWithCenter:center radius:radius startAngle:90 endAngle:90-(360*value) clockwise:YES];
        arc.lineWidth = width; arc.lineCapStyle = NSLineCapStyleRound;
        [[self colorForValue:value] setStroke]; [arc stroke];
    }
    [[NSColor.labelColor colorWithAlphaComponent:.75] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x-2, center.y-2, 4, 4)] fill];
}
- (void)mouseDown:(NSEvent *)event {
    self.dragStart = NSEvent.mouseLocation; self.windowStart = self.window.frame.origin; self.didDrag = NO;
}
- (void)mouseDragged:(NSEvent *)event {
    NSPoint current = NSEvent.mouseLocation;
    CGFloat dx = current.x-self.dragStart.x, dy = current.y-self.dragStart.y;
    if (hypot(dx, dy) > 3) self.didDrag = YES;
    [self.window setFrameOrigin:NSMakePoint(self.windowStart.x+dx, self.windowStart.y+dy)];
}
- (void)mouseUp:(NSEvent *)event {
    if (self.didDrag) {
        NSPoint position = self.window.frame.origin;
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        [defaults setDouble:position.x forKey:@"windowPositionX"];
        [defaults setDouble:position.y forKey:@"windowPositionY"];
        [defaults setBool:YES forKey:@"hasSavedWindowPosition"];
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:@"/System/Applications/Utilities/Activity Monitor.app"];
    [[NSWorkspace sharedWorkspace] openApplicationAtURL:url configuration:[NSWorkspaceOpenConfiguration configuration] completionHandler:nil];
}
- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSMenu *menu = [NSMenu new];
    NSMenuItem *open = [[NSMenuItem alloc] initWithTitle:@"Open Activity Monitor" action:@selector(openActivityMonitor:) keyEquivalent:@""];
    open.target = self; [menu addItem:open]; [menu addItem:NSMenuItem.separatorItem];
    NSView *shadeView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 210, 48)];
    NSTextField *label = [NSTextField labelWithString:@"Background shade"];
    label.frame = NSMakeRect(14, 27, 182, 16); label.font = [NSFont menuFontOfSize:12];
    NSSlider *slider = [NSSlider sliderWithValue:self.backgroundShade minValue:.08 maxValue:.90 target:self action:@selector(shadeChanged:)];
    slider.frame = NSMakeRect(12, 3, 186, 24); slider.continuous = YES;
    [shadeView addSubview:label]; [shadeView addSubview:slider];
    NSMenuItem *shadeItem = [NSMenuItem new]; shadeItem.view = shadeView; [menu addItem:shadeItem];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit ResourceRing" action:@selector(terminate:) keyEquivalent:@""];
    quit.target = NSApp; [menu addItem:quit]; return menu;
}
- (void)shadeChanged:(NSSlider *)sender {
    self.backgroundShade = sender.doubleValue;
    NSView *background = self.window.contentView;
    background.layer.backgroundColor = [NSColor colorWithCalibratedWhite:self.backgroundShade alpha:.58].CGColor;
    [[NSUserDefaults standardUserDefaults] setDouble:self.backgroundShade forKey:@"backgroundShade"];
}
- (void)openActivityMonitor:(id)sender {
    NSURL *url = [NSURL fileURLWithPath:@"/System/Applications/Utilities/Activity Monitor.app"];
    [[NSWorkspace sharedWorkspace] openApplicationAtURL:url configuration:[NSWorkspaceOpenConfiguration configuration] completionHandler:nil];
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    uint32_t _previous[CPU_STATE_MAX];
}
@property NSPanel *panel;
@property NSPanel *infoPanel;
@property NSTextField *infoLabel;
@property RingView *ring;
@property BOOL hasPrevious;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    NSRect rect = NSMakeRect(0, 0, 54, 54);
    self.panel = [[NSPanel alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    self.panel.level = NSFloatingWindowLevel;
    self.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorStationary;
    self.panel.opaque = NO; self.panel.backgroundColor = NSColor.clearColor; self.panel.hasShadow = NO;
    NSView *background = [[NSView alloc] initWithFrame:rect];
    background.wantsLayer = YES;
    NSNumber *savedShade = [[NSUserDefaults standardUserDefaults] objectForKey:@"backgroundShade"];
    double initialShade = savedShade ? savedShade.doubleValue : .48;
    background.layer.backgroundColor = [NSColor colorWithCalibratedWhite:initialShade alpha:.58].CGColor;
    background.layer.cornerRadius = 27;
    background.layer.shadowColor = NSColor.blackColor.CGColor;
    background.layer.shadowOpacity = .16;
    background.layer.shadowRadius = 7;
    background.layer.shadowOffset = NSMakeSize(0, -2);
    background.layer.shadowPath = CGPathCreateWithEllipseInRect(CGRectInset(NSRectToCGRect(rect), 2, 2), NULL);
    self.ring = [[RingView alloc] initWithFrame:rect]; self.ring.backgroundShade = initialShade;
    [background addSubview:self.ring]; self.panel.contentView = background;
    __weak AppDelegate *weakSelf = self;
    self.ring.hoverChanged = ^(BOOL inside) { inside ? [weakSelf showInfo] : [weakSelf hideInfo]; };
    [self makeInfoPanel];
    [self reposition]; [self.panel orderFrontRegardless]; [self refresh];
    [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reposition) name:NSApplicationDidChangeScreenParametersNotification object:nil];
}
- (void)makeInfoPanel {
    NSRect rect = NSMakeRect(0, 0, 154, 54);
    self.infoPanel = [[NSPanel alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel backing:NSBackingStoreBuffered defer:NO];
    self.infoPanel.level = NSFloatingWindowLevel; self.infoPanel.opaque = NO; self.infoPanel.backgroundColor = NSColor.clearColor; self.infoPanel.hasShadow = YES;
    self.infoPanel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces|NSWindowCollectionBehaviorFullScreenAuxiliary;
    NSVisualEffectView *background = [[NSVisualEffectView alloc] initWithFrame:rect];
    background.material = NSVisualEffectMaterialHUDWindow; background.state = NSVisualEffectStateActive; background.wantsLayer = YES; background.layer.cornerRadius = 12; background.layer.masksToBounds = YES;
    self.infoLabel = [NSTextField labelWithString:@""]; self.infoLabel.frame = NSInsetRect(rect, 12, 8); self.infoLabel.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightMedium]; self.infoLabel.maximumNumberOfLines = 2;
    [background addSubview:self.infoLabel]; self.infoPanel.contentView = background;
}
- (void)showInfo {
    NSRect ringFrame = self.panel.frame; NSScreen *screen = self.panel.screen ?: NSScreen.mainScreen;
    CGFloat x = NSMaxX(ringFrame)+8; if (x+self.infoPanel.frame.size.width > NSMaxX(screen.visibleFrame)) x = NSMinX(ringFrame)-self.infoPanel.frame.size.width-8;
    [self.infoPanel setFrameOrigin:NSMakePoint(x, NSMidY(ringFrame)-self.infoPanel.frame.size.height/2)]; [self.infoPanel orderFrontRegardless];
}
- (void)hideInfo { [self.infoPanel orderOut:nil]; }
- (void)reposition {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSInteger positionVersion = [defaults integerForKey:@"positionCoordinateVersion"];
    if (positionVersion < 2) {
        [defaults removeObjectForKey:@"hasSavedWindowPosition"];
        [defaults removeObjectForKey:@"windowPositionX"];
        [defaults removeObjectForKey:@"windowPositionY"];
        [defaults setInteger:2 forKey:@"positionCoordinateVersion"];
    }
    BOOL hasSavedPosition = [defaults boolForKey:@"hasSavedWindowPosition"];
    NSScreen *screen = NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    NSPoint position;

    if (hasSavedPosition) {
        position = NSMakePoint([defaults doubleForKey:@"windowPositionX"], [defaults doubleForKey:@"windowPositionY"]);
        NSPoint center = NSMakePoint(position.x + NSWidth(self.panel.frame) / 2, position.y + NSHeight(self.panel.frame) / 2);
        for (NSScreen *candidate in NSScreen.screens) {
            if (NSPointInRect(center, candidate.frame)) { screen = candidate; break; }
        }
    } else {
        NSRect frame = screen.frame;
        CGFloat margin = 16;
        position = NSMakePoint(NSMaxX(frame) - NSWidth(self.panel.frame) - margin, NSMinY(frame) + margin);
    }

    NSRect displayFrame = screen.frame;
    position.x = MAX(NSMinX(displayFrame), MIN(position.x, NSMaxX(displayFrame) - NSWidth(self.panel.frame)));
    position.y = MAX(NSMinY(displayFrame), MIN(position.y, NSMaxY(displayFrame) - NSHeight(self.panel.frame)));
    [self.panel setFrameOrigin:position];
}
- (double)cpuUsage {
    host_cpu_load_info_data_t info; mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&info, &count) != KERN_SUCCESS) return 0;
    uint64_t total = 0, idle = 0;
    for (int i=0; i<CPU_STATE_MAX; i++) { uint32_t current=info.cpu_ticks[i]; uint64_t delta=self.hasPrevious ? (uint32_t)(current-_previous[i]) : 0; total+=delta; if(i==CPU_STATE_IDLE) idle=delta; _previous[i]=current; }
    self.hasPrevious = YES; return total ? (double)(total-idle)/(double)total : 0;
}
- (double)memoryUsage {
    vm_size_t pageSize=0; host_page_size(mach_host_self(), &pageSize); vm_statistics64_data_t info; mach_msg_type_number_t count=HOST_VM_INFO64_COUNT;
    if(host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&info, &count)!=KERN_SUCCESS) return 0;
    double total=(double)NSProcessInfo.processInfo.physicalMemory, available=(double)(info.free_count+info.inactive_count)*(double)pageSize;
    return MAX(0, MIN(1, (total-available)/total));
}
- (void)refresh {
    self.ring.cpu=[self cpuUsage]; self.ring.memory=[self memoryUsage];
    self.infoLabel.stringValue=[NSString stringWithFormat:@"CPU       %.0f%%\nMemory    %.0f%%",self.ring.cpu*100,self.ring.memory*100];
    [self.ring setNeedsDisplay:YES];
}
@end

int main(void) { @autoreleasepool { NSApplication *app=NSApplication.sharedApplication; AppDelegate *delegate=[AppDelegate new]; app.delegate=delegate; [app run]; } }
