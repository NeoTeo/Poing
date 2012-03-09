//
//  PoingView.m
//  Poing
//
//  Created by Matteo Sartori on 01/03/12.
//  Copyright (c) 2012 I Love You Bits. All rights reserved.
//

#import "PoingView.h"
#import <QuartzCore/QuartzCore.h>
#import <mach/mach_time.h>

#define MAXIMUM_FRAME_RATE 120
#define MINIMUM_FRAME_RATE 15
#define UPDATE_INTERVAL (1.0 / MAXIMUM_FRAME_RATE)
#define MAX_CYCLES_PER_FRAME (MAXIMUM_FRAME_RATE / MINIMUM_FRAME_RATE)

@implementation PoingView

@synthesize displayLink;
static bool arse = YES;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        /*
        // Begin by initializing the data structures.
        pointArray = [[NSMutableArray alloc] initWithObjects:
                      [NSValue valueWithCGPoint:CGPointMake(1, 1)],
                      [NSValue valueWithCGPoint:CGPointMake(150, 200)],
                      [NSValue valueWithCGPoint:CGPointMake(250, 320)],
                      [NSValue valueWithCGPoint:CGPointMake(10, 350)],
                      [NSValue valueWithCGPoint:CGPointMake(100, 400)],
                      [NSValue valueWithCGPoint:CGPointMake(120, 420)],
                      [NSValue valueWithCGPoint:CGPointMake(50, 510)],
                      [NSValue valueWithCGPoint:CGPointMake(350, 520)],
                      [NSValue valueWithCGPoint:CGPointMake(20, 630)],
                      nil];
         */ 
        // static because we want the array to remain outside the scope of the function,
        static Vector3 tmpPoints[NUM_PARTICLES] = {
            {320,50,0},
            {320,150,0},
            {320,300,0}};
        
        userPosition.x = tmpPoints[0].x;
        userPosition.y = tmpPoints[0].y;    
        
        currentPositions = tmpPoints;

        gravity.x = 0.0;
        gravity.y = 2;
        
        timeStep = 1;
        
        // start off with a static system.
        for (int curIndex=0; curIndex < NUM_PARTICLES; curIndex++) 
        {
            previousPositions[curIndex] = currentPositions[curIndex];
        }
        
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(setNeedsDisplay)];
        
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        
        NSLog(@"Initialization done.");

    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    NSLog(@"Setup");

    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (double)getCurrentTime
{
    static mach_timebase_info_data_t sTimebaseInfo;
    uint64_t time = mach_absolute_time();
    uint64_t nanos;
    
    // If this is the first time we've run, get the timebase.
    // We can use denom == 0 to indicate that sTimebaseInfo is
    // uninitialised because it makes no sense to have a zero
    // denominator is a fraction.
    if (sTimebaseInfo.denom == 0) {
        (void)mach_timebase_info(&sTimebaseInfo);
    }
    
    // Do the maths.  We hope that the multiplication doesn't
    // overflow; the price you pay for working in fixed point.
    nanos = time * sTimebaseInfo.numer / sTimebaseInfo.denom;
    return ((double)nanos / 1000000000.0);
}

- (void)accumulateForces
{
    for (int curIndex=0; curIndex < NUM_PARTICLES; curIndex++) 
    {
        forceAccumulators[curIndex] = gravity;
    }
}

- (void)movePointsUsingVerletIntegration
{
    arse=NO;

    for (int curIndex=0; curIndex < NUM_PARTICLES; curIndex++) 
    {
        if (arse)
            NSLog(@"the current pos for index %d is %f,%f",curIndex,currentPositions[curIndex].x,currentPositions[curIndex].y);
        
        // x points to the current position
        Vector3 *x = &currentPositions[curIndex];
        // temp is a copy of the current position
        Vector3 temp = currentPositions[curIndex];
        
        // oldPos is a reference to the previous position
        Vector3 *oldPos = &previousPositions[curIndex];
        if (arse)
            NSLog(@"oldPos is %f,%f",oldPos->x,oldPos->y);
        
        // a is a reference the accumulated force
        Vector3 *a = &forceAccumulators[curIndex];
        if (arse)
            NSLog(@"a is %f,%f",a->x,a->y);
        
        // Verlet integration: x += x-oldPos+a*(timeStep*timeStep) ;
        x->x += x->x-oldPos->x+a->x*timeStep*timeStep;
        x->y += x->y-oldPos->y+a->y*timeStep*timeStep;
        if (arse) 
            NSLog(@"result is is %f,%f",x->x,x->y);
        *oldPos = temp;
    }
    
    currentPositions[0].x = userPosition.x;
    currentPositions[0].y = userPosition.y;    
}

- (void)satisfyConstraints
{

    float restLength = 50;
    for (int j=0; j < NUM_ITERATIONS; j++) {
        // quick bodge for three points
        for (int p=0; p<3; p++) 
        {
            
            Vector3 *x1 = &currentPositions[p];
            Vector3 *x2 = &currentPositions[p+1];
            Vector3 delta;
            delta.x = x2->x-x1->x;
            delta.y = x2->y-x1->y;
            // dot product of the delta.
            float deltadot = delta.x*delta.x+delta.y*delta.y;
            // find length
            float deltaLength = sqrtf(deltadot);
            float diff = (deltaLength-restLength)/deltaLength;
            /*
            if (arse)
            {
                NSLog(@"Delta is %f,%f",delta.x,delta.y);
                NSLog(@"deltadot os %f",deltadot);
                NSLog(@"deltalength os %f",deltaLength);
                NSLog(@"Before");            
                NSLog(@"x1 is %f,%f",x1->x,x1->y);
                NSLog(@"x2 is %f,%f",x2->x,x2->y);
            }
            */
            x1->x += delta.x*0.5*diff;
            x1->y += delta.y*0.5*diff;
            
            x2->x -= delta.x*0.5*diff;
            x2->y -= delta.y*0.5*diff;        
            /*
            if (arse) {
                NSLog(@"After");
                NSLog(@"x1 is %f,%f",x1->x,x1->y);
                NSLog(@"x2 is %f,%f",x2->x,x2->y);
            }
             */
        }
    }
    
}


- (void)updateGame
{
    
    [self accumulateForces];
    [self movePointsUsingVerletIntegration];
    [self satisfyConstraints];
    
    // debug output
    if (arse) {
        arse = NO;
    }
}

- (void)drawScene
{

    CGContextRef myContext = UIGraphicsGetCurrentContext();
    
    CGContextBeginPath(myContext);
    
    for (int curIndex=0; curIndex < NUM_PARTICLES; curIndex++)
    {
        
        // ********** Your drawing code here **********
        // The first point is where we move to, subsequent points we draw lines to. 
        if (!curIndex) {
            CGContextMoveToPoint(myContext, currentPositions[curIndex].x, currentPositions[curIndex].y);
        } else
        {
            CGContextAddLineToPoint(myContext, currentPositions[curIndex].x, currentPositions[curIndex].y);
        }
    }
    CGContextStrokePath(myContext);
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    CGPoint location = [[touches anyObject] locationInView:self];
    
    userPosition.x = location.x;
    userPosition.y = location.y;
    NSLog(@"Touched at %f,%f",location.x,location.y);
    arse = YES;

}

- (void)MSEngineTick
{
    static double lastFrameTime = 0.0;
    static double cyclesLeftOver = 0.0;
    double currentTime;
    double updateIterations;
    
    currentTime = [self getCurrentTime];
    updateIterations = ((currentTime - lastFrameTime) + cyclesLeftOver);
    
    if (updateIterations > (MAX_CYCLES_PER_FRAME * UPDATE_INTERVAL)) {
        updateIterations = (MAX_CYCLES_PER_FRAME * UPDATE_INTERVAL);
    }
    //NSLog(@"Update iterations %f",updateIterations);
    while (updateIterations > UPDATE_INTERVAL) {
        updateIterations -= UPDATE_INTERVAL;
        
        [self updateGame]; /* Update game state a variable number of times */
    }
    
    cyclesLeftOver = updateIterations;
    if (lastFrameTime == 0.0) {
        lastFrameTime = [self getCurrentTime];
    }
    lastFrameTime = currentTime;
    
    //drawScene(); /* Draw the scene only once */    

    [self drawScene];
}
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    [self MSEngineTick];
}


@end
