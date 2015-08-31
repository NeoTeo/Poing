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

#define MAXIMUM_FRAME_RATE      120
#define MINIMUM_FRAME_RATE      15
#define UPDATE_INTERVAL         (1.0 / MAXIMUM_FRAME_RATE)
#define MAX_CYCLES_PER_FRAME    (MAXIMUM_FRAME_RATE / MINIMUM_FRAME_RATE)

@implementation PoingView

@synthesize displayLink;


- (void)vmin:(Vector3 *)a  against:(Vector3 *)b into:(Vector3 *)c
{
    
    c->x = a->x < b->x ? a->x : b->x;
    c->y = a->y < b->y ? a->y : b->y;
    c->z = a->z < b->z ? a->z : b->z;
}

- (void)vmax:(Vector3 *)a  against:(Vector3 *)b into:(Vector3 *)c
{
    c->x = a->x > b->x ? a->x : b->x;
    c->y = a->y > b->y ? a->y : b->y;
    c->z = a->z > b->z ? a->z : b->z;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // static because we want the array to persist outside the scope of the function.
        static Vector3 tmpPoints[NUM_PARTICLES];
        
        int ypos = 0;
        int yoff = MAX_LEN/NUM_PARTICLES;
        
        for (int pt=0; pt<NUM_PARTICLES; pt++) {
            
            tmpPoints[pt].x = 320;
            tmpPoints[pt].y = ypos;
            tmpPoints[pt].z = 0;
            
            ypos += yoff;
        }
        
        userPosition1.x     = tmpPoints[0].x;
        userPosition1.y     = tmpPoints[0].y;
        userPosition2.x     = tmpPoints[NUM_PARTICLES-1].x;
        userPosition2.y     = tmpPoints[NUM_PARTICLES-1].y;
        
        twoFingered         = NO;
        
        currentPositions    = tmpPoints;

        gravity.x           = 0.0;
        gravity.y           = 1;
        
        timeStep            = 1;
        
        
        // Start off with a static system.
        for (int curIndex=0; curIndex < NUM_PARTICLES; curIndex++) 
        {
            previousPositions[curIndex] = currentPositions[curIndex];
        }
        
        for (int curIndex=0; curIndex < NUM_CONSTRAINTS; curIndex++) 
        {
            constraints[curIndex].particleAIndex = curIndex;
            constraints[curIndex].particleBIndex = curIndex+1;
            constraints[curIndex].restLength = yoff;
        }
        
        // Ball init.
        ballPos.x       = 10;
        ballPos.y       = 10;
        ballPos.z       = 10;
        
        ballPrevPos.x   = ballPos.x-0.001;
        ballPrevPos.y   = ballPos.y-0.001;
        ballPrevPos.z   = ballPos.z;
        
        ballForce.x     = ballForce.y = ballForce.z = 1;
        
        // Registering a selector with CADisplayLink allows you to be notified at every vsync.
        displayLink     = [CADisplayLink displayLinkWithTarget:self selector:@selector(setNeedsDisplay)];
        
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        
        NSLog(@"Initialization done.");

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
    // denominator in a fraction.
    if (sTimebaseInfo.denom == 0) {
        (void)mach_timebase_info(&sTimebaseInfo);
    }
    
    // Do the maths.  We hope that the multiplication doesn't
    // overflow; the price you pay for working in fixed point.
    nanos = time * sTimebaseInfo.numer / sTimebaseInfo.denom;
    return ((double)nanos / 1000000000.0);
}

- (void)accumulateForces:(Vector3 *)forceAccumulatorArray ofCount:(int)particleCount
{
    for (int curIndex=0; curIndex < particleCount; curIndex++) 
    {
        forceAccumulatorArray[curIndex] = gravity;
    }
}

- (void)moveParticlesUsingVerletIntegration:(Vector3 *)particlePosArray 
                                    ofCount:(int)particleCount 
                      withPreviousPositions:(Vector3 *)particlePreviousPosArray 
                                 withForces:(Vector3 *)forcesArray
{
    float timeStepSquared = timeStep*timeStep;
    for (int curIndex=0; curIndex < particleCount; curIndex++) 
    {        
        // x points to the current position
        Vector3 *x = &particlePosArray[curIndex];
        
        // temp is a copy of the current position
        Vector3 temp = particlePosArray[curIndex];
        
        // oldPos is a reference to the previous position
        Vector3 *oldPos = &particlePreviousPosArray[curIndex];
        
        // a is a reference the accumulated force
        Vector3 *a = &forcesArray[curIndex];
        
        // Verlet integration: x += x-oldPos+a*(timeStep*timeStep) ;
        x->x += x->x-oldPos->x+a->x*timeStepSquared;
        x->y += x->y-oldPos->y+a->y*timeStepSquared;
        
        *oldPos = temp;
    }
}

- (void)satisfyConstraintsOf:(Vector3 *)particleArray 
                     ofCount:(int)particleCount 
             withConstraints:(Constraint *)constraintArray 
                     ofCount:(int)constraintCount
{

    for (int p=0; p<constraintCount; p++)
    {
        Constraint c    = constraintArray[p];
        
        Vector3 *x1     = &particleArray[c.particleAIndex];
        Vector3 *x2     = &particleArray[c.particleBIndex];
        Vector3 delta;
        
        delta.x         = x2->x-x1->x;
        delta.y         = x2->y-x1->y;

        // The version with square root approximation.
        float restLengthSqr = c.restLength*c.restLength;
        float deltaDot      = delta.x*delta.x + delta.y*delta.y;
        
        // As long as the deltaDot is greater than the restLengthSqr the sign of the expression 
        // will be negative unless I move the 0.5 before rather than after.
        delta.x *= 0.5-restLengthSqr/(deltaDot+restLengthSqr);//-0.5;
        delta.y *= 0.5-restLengthSqr/(deltaDot+restLengthSqr);//-0.5;
        
        x1->x += delta.x;
        x1->y += delta.y;
        x2->x -= delta.x;
        x2->y -= delta.y;
    }
}

- (void)satisfyElasticConstraints
{
    // This allows for custom iterations for the elastic.
    for (int j=0; j<NUM_ITERATIONS; j++) 
    {
        [self satisfyConstraintsOf:currentPositions ofCount:NUM_PARTICLES withConstraints:constraints ofCount:NUM_CONSTRAINTS];    
        
        // constrain position 0 to the position selected by the user.
        currentPositions[0].x = userPosition1.x;
        currentPositions[0].y = userPosition1.y;    
        
        if (twoFingered) {
            currentPositions[NUM_PARTICLES-1].x = userPosition2.x;
            currentPositions[NUM_PARTICLES-1].y = userPosition2.y;    
        }
    }
}

- (void)accumulateElasticForces
{
    [self accumulateForces:forceAccumulators ofCount:NUM_PARTICLES];
}

- (void)moveElasticUsingVerletIntegration
{
    [self moveParticlesUsingVerletIntegration:currentPositions ofCount:NUM_PARTICLES withPreviousPositions:previousPositions withForces:forceAccumulators];
}

- (void)satisfyBallConstraints
{
    // Do a bounds check run. 
    // MinVector and maxVector define a square bounds.
    Vector3 minVector = {0,0,0};
    Vector3 maxVector = {700,700,0};
    [self vmax:&ballPos against:&minVector into:&ballPos];
    [self vmin:&ballPos against:&maxVector into:&ballPos];
    
    // Check against elastic.
    
}

- (void)updateGame
{    
    //CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    [self accumulateElasticForces];
    [self moveElasticUsingVerletIntegration];
    [self satisfyElasticConstraints];
    //CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    //NSLog(@"Time spent on update loop is %f",end-start);
    
    // Ball stuff
    [self moveParticlesUsingVerletIntegration:&ballPos ofCount:1 withPreviousPositions:&ballPrevPos withForces:&ballForce];
    [self satisfyBallConstraints];
}

- (void)drawScene
{

    CGContextRef myContext = UIGraphicsGetCurrentContext();
    
    CGContextBeginPath(myContext);
    // The first point is where we move to.
    CGContextMoveToPoint(myContext, currentPositions[0].x, currentPositions[0].y);
    
    for (int curIndex=1; curIndex < NUM_PARTICLES; curIndex++)
    {
        // Subsequent points we draw lines to. 
        CGContextAddLineToPoint(myContext, currentPositions[curIndex].x, currentPositions[curIndex].y);
    }
        
    CGContextStrokePath(myContext);
    
    // Bodge to add ball
    CGRect ballRect = CGRectMake(ballPos.x-10, ballPos.y-10, 20, 20);
    CGContextFillEllipseInRect(myContext, ballRect);
}


// TouchesBegan only received new or changed touch events. 
// We can, however, get at all tracked touches through the event parameter.
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    int counter         = 0;
    NSSet *allMyTouches = [event allTouches];
    
    for (UITouch *touch in allMyTouches) {

        if (counter == 0) {
            CGPoint location = [touch locationInView:self];
            userPosition1.x = location.x;
            userPosition1.y = location.y;
            NSLog(@"one touch fine");
        }
        
        // only fix the second positon if there is more than one touch and we are at the last touch.
        if (counter && (counter == touches.count-1)) {
            CGPoint location = [touch locationInView:self];
            userPosition2.x = location.x;
            userPosition2.y = location.y;
            twoFingered = YES;
            NSLog(@"Second finger at %f,%f",location.x,location.y);
        }
        counter++;
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    int counter         = 0;
    NSSet *allMyTouches = [event allTouches];
    
    for (UITouch *touch in allMyTouches) {

        if (counter == 0) {
            CGPoint location = [touch locationInView:self];
            userPosition1.x = location.x;
            userPosition1.y = location.y;
        }
        
        // only fix the second positon if there is more than one touch and we are at the last touch.
        if (counter && (counter == touches.count-1)) {
            CGPoint location = [touch locationInView:self];
            userPosition2.x = location.x;
            userPosition2.y = location.y;
            twoFingered = YES;
        }
        counter++;
    }
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (touches.count < 2) {
        twoFingered = NO;
    }
}

- (void)MSEngineTick
{
    static double lastFrameTime     = 0.0;
    static double cyclesLeftOver    = 0.0;
    double currentTime;
    double updateIterations;
    
    currentTime = [self getCurrentTime];
    updateIterations = ((currentTime - lastFrameTime) + cyclesLeftOver);
    
    if (updateIterations > (MAX_CYCLES_PER_FRAME * UPDATE_INTERVAL)) {
        updateIterations = (MAX_CYCLES_PER_FRAME * UPDATE_INTERVAL);
    }

    while (updateIterations > UPDATE_INTERVAL) {
        updateIterations -= UPDATE_INTERVAL;
        
        [self updateGame]; /* Update game state a variable number of times */
    }
    
    cyclesLeftOver = updateIterations;
    if (lastFrameTime == 0.0) {
        lastFrameTime = [self getCurrentTime];
    }
    lastFrameTime = currentTime;

    [self drawScene];
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
// This is called every vsync by CADisplayLink
- (void)drawRect:(CGRect)rect
{
    [self MSEngineTick];
}


@end
