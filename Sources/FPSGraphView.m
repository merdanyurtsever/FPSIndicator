#import "FPSGraphView.h"

@implementation FPSGraphView {
    NSMutableArray<NSNumber *> *_frameTimeHistory;
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupDefaults];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self setupDefaults];
    }
    return self;
}

- (void)setupDefaults {
    // Default properties
    _frameTimeHistory = [NSMutableArray array];
    _historySize = 100; // Store last 100 frames
    _maxFrameTime = 33.3; // Display up to 33.3ms (30 FPS)
    _showThreshold = YES;
    
    // Default colors
    if (@available(iOS 13.0, *)) {
        _graphColor = [UIColor systemGreenColor];
        _graphBackgroundColor = [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.8];
        _thresholdColor = [UIColor systemRedColor];
    } else {
        _graphColor = [UIColor greenColor];
        _graphBackgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        _thresholdColor = [UIColor redColor];
    }
    
    // Make the graph view semi-transparent
    self.layer.cornerRadius = 6.0;
    self.layer.masksToBounds = YES;
    self.clipsToBounds = YES;
}

#pragma mark - Public Methods

- (void)addFrameTime:(double)frameTime {
    // Add the new frame time
    [_frameTimeHistory addObject:@(frameTime)];
    
    // Keep only the last historySize items
    while (_frameTimeHistory.count > _historySize) {
        [_frameTimeHistory removeObjectAtIndex:0];
    }
    
    // Trigger redraw
    [self setNeedsDisplay];
}

- (void)clearHistory {
    [_frameTimeHistory removeAllObjects];
    [self setNeedsDisplay];
}

- (NSArray<NSNumber *> *)frameTimeHistory {
    return [_frameTimeHistory copy];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    
    // Fill background
    CGContextSetFillColorWithColor(context, self.graphBackgroundColor.CGColor);
    CGContextFillRect(context, rect);
    
    // Draw threshold line at 16.7ms (60 FPS)
    if (_showThreshold) {
        double thresholdY = rect.size.height * (1.0 - (16.7 / _maxFrameTime));
        thresholdY = MAX(0, MIN(thresholdY, rect.size.height));
        
        // Draw threshold line as a dashed line
        CGContextSetStrokeColorWithColor(context, _thresholdColor.CGColor);
        CGContextSetLineWidth(context, 1.0);
        
        // Create dashed pattern
        CGFloat dashes[] = {3, 3};
        CGContextSetLineDash(context, 0, dashes, 2);
        
        CGContextMoveToPoint(context, 0, thresholdY);
        CGContextAddLineToPoint(context, rect.size.width, thresholdY);
        CGContextStrokePath(context);
        
        // Reset dash pattern
        CGContextSetLineDash(context, 0, NULL, 0);
    }
    
    // Draw frame time graph
    NSInteger count = _frameTimeHistory.count;
    if (count < 2) return; // Need at least 2 points to draw a line
    
    CGContextSetStrokeColorWithColor(context, _graphColor.CGColor);
    CGContextSetLineWidth(context, 1.5);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    
    // Calculate horizontal spacing
    CGFloat xStep = rect.size.width / (CGFloat)(_historySize - 1);
    
    // Start path at the first point
    double firstFrameTime = [_frameTimeHistory[0] doubleValue];
    double normalizedTime = firstFrameTime / _maxFrameTime;
    normalizedTime = MAX(0, MIN(normalizedTime, 1.0)); // Clamp to 0-1
    
    CGFloat y = rect.size.height * (1.0 - normalizedTime);
    CGContextMoveToPoint(context, 0, y);
    
    // Add points to the path
    for (NSInteger i = 1; i < count; i++) {
        double frameTime = [_frameTimeHistory[i] doubleValue];
        normalizedTime = frameTime / _maxFrameTime;
        normalizedTime = MAX(0, MIN(normalizedTime, 1.0)); // Clamp to 0-1
        
        CGFloat x = i * xStep;
        y = rect.size.height * (1.0 - normalizedTime);
        
        CGContextAddLineToPoint(context, x, y);
    }
    
    // Stroke the path
    CGContextStrokePath(context);
    
    // Draw last value as text
    if (count > 0) {
        double lastFrameTime = [_frameTimeHistory.lastObject doubleValue];
        NSString *frameTimeText = [NSString stringWithFormat:@"%.1f ms", lastFrameTime];
        
        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:10],
            NSForegroundColorAttributeName: _graphColor
        };
        
        CGSize textSize = [frameTimeText sizeWithAttributes:attributes];
        CGRect textRect = CGRectMake(
            rect.size.width - textSize.width - 4,
            4,
            textSize.width,
            textSize.height
        );
        
        [frameTimeText drawInRect:textRect withAttributes:attributes];
    }
}

@end