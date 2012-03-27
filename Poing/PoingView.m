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


- (Vector3)vmin:(Vector3 *)a  against:(Vector3 *)b
{
    Vector3 newVector;
    
    newVector.x = a->x < b->x ? a->x : b->x;
    newVector.y = a->y < b->y ? a->y : b->y;
    newVector.z = a->z < b->z ? a->z : b->z;
    
    return  newVector;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        Vector3 t1 = {2,4,3};
        Vector3 t2 = {2,3,9};
        Vector3 r1 = {0,0,0};
        
        r1 = [self vmin:&t1 against:&t2];
        NSLog(@"vmin returned %f,%f,%f",r1.x,r1.y,r1.z);
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
        // static because we want the array to persist outside the scope of the function.
        static Vector3 tmpPoints[NUM_PARTICLES];// = {
/*        
            {320,50,0},
            {320,100,0},
            {320,150,0},            
            {320,200,0},
            {320,250,0},
            {320,300,0},
            {320,350,0},
            {320,400,0},
            {320,450,0},
            {320,500,0},
            {320,550,0},
            {320,600,0}};
*/
        int ypos = 0;
        int yoff = MAX_LEN/NUM_PARTICLES;
        for (int pt=0; pt<NUM_PARTICLES; pt++) {
            tmpPoints[pt].x = 320;
            tmpPoints[pt].y = ypos;
            tmpPoints[pt].z = 0;
            ypos += yoff;
        }
        userPosition1.x = tmpPoints[0].x;
        userPosition1.y = tmpPoints[0].y; 
        
        twoFingered = NO;
        userPosition2.x = tmpPoints[NUM_PARTICLES-1].x;
        userPosition2.y = tmpPoints[NUM_PARTICLES-1].y;
        
        currentPositions = tmpPoints;

        gravity.x = 0.0;
        gravity.y = 1;
        
        timeStep = 1;
        
        // start off with a static system.
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
        
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(setNeedsDisplay)];
        
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        
        NSLog(@"Initialization done.");

    }
    return self;
}
/*
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}
*/

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

- (void)accumulateForces
{
    for (int curIndex=0; curIndex < NUM_PARTICLES; curIndex++) 
    {
        forceAccumulators[curIndex] = gravity;
    }
}

- (void)movePointsUsingVerletIntegration
{
    float timeStepSquared = timeStep*timeStep;
    for (int curIndex=0; curIndex < NUM_PARTICLES; curIndex++) 
    {        
        // x points to the current position
        Vector3 *x = &currentPositions[curIndex];
        // temp is a copy of the current position
        Vector3 temp = currentPositions[curIndex];
        
        // oldPos is a reference to the previous position
        Vector3 *oldPos = &previousPositions[curIndex];
        // a is a reference the accumulated force
        Vector3 *a = &forceAccumulators[curIndex];
        // Verlet integration: x += x-oldPos+a*(timeStep*timeStep) ;
        x->x += x->x-oldPos->x+a->x*timeStepSquared;
        x->y += x->y-oldPos->y+a->y*timeStepSquared;
        *oldPos = temp;
    }
}

- (void)satisfyConstraints
{
    for (int j=0; j<NUM_ITERATIONS; j++) {
        for (int p=0; p<NUM_CONSTRAINTS; p++) 
        {
            Constraint c = constraints[p];
            
            Vector3 *x1 = &currentPositions[c.particleAIndex];
            Vector3 *x2 = &currentPositions[c.particleBIndex];
            Vector3 delta;
                    
            delta.x = x2->x-x1->x;
            delta.y = x2->y-x1->y;
#if 1           
            // The version with square root approximation.
            float restLengthSqr = c.restLength*c.restLength;
            float deltaDot = delta.x*delta.x + delta.y*delta.y;
            // As long as the deltaDot is greater than the restLengthSqr the sign of the expression 
            // will be negative unless I move the 0.5 before rather than after.
            delta.x *= 0.5-restLengthSqr/(deltaDot+restLengthSqr);//-0.5;
            delta.y *= 0.5-restLengthSqr/(deltaDot+restLengthSqr);//-0.5;

            x1->x += delta.x;
            x1->y += delta.y;
            x2->x -= delta.x;
            x2->y -= delta.y;
#else
             // The version with a square root call.
             // dot product of the delta.
             float deltadot = delta.x*delta.x+delta.y*delta.y;
             // find length
             float deltaLength = sqrtf(deltadot);
             float diff = (deltaLength-c.restLength)/deltaLength;
             // Each point takes half (0.5) of the difference in distance (diff) 
             // and adds to one (x1) and subracts from the other (x2) so they converge.
             // I think...
             x1->x += delta.x*0.5*diff;
             x1->y += delta.y*0.5*diff;
             
             x2->x -= delta.x*0.5*diff;
             x2->y -= delta.y*0.5*diff;        
#endif
        }
        // constrain position 0 to the position selected by the user.
        currentPositions[0].x = userPosition1.x;
        currentPositions[0].y = userPosition1.y;    

        if (twoFingered) {
            currentPositions[NUM_PARTICLES-1].x = userPosition2.x;
            currentPositions[NUM_PARTICLES-1].y = userPosition2.y;    
        }

    }
}


- (void)updateGame
{    
    [self accumulateForces];
    [self movePointsUsingVerletIntegration];
    [self satisfyConstraints];
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
    int counter =0;
    NSSet *allMyTouches = [event allTouches];
    for (UITouch *touch in allMyTouches) {

        if (counter == 0) {
            CGPoint location = [touch locationInView:self];
            userPosition1.x = location.x;
            userPosition1.y = location.y;
            NSLog(@"one touch fine");
        }
        // only fix the second positon if there is more than one touch and we are at the last touch.
        if (counter && (counter == [touches count]-1)) {
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
    int counter =0;
    NSSet *allMyTouches = [event allTouches];
    for (UITouch *touch in allMyTouches) {

        if (counter == 0) {
            CGPoint location = [touch locationInView:self];
            userPosition1.x = location.x;
            userPosition1.y = location.y;
        }
        // only fix the second positon if there is more than one touch and we are at the last touch.
        if (counter && (counter == [touches count]-1)) {
            CGPoint location = [touch locationInView:self];
            userPosition2.x = location.x;
            userPosition2.y = location.y;
            twoFingered = YES;
                        NSLog(@"Second finger moved at %f,%f",location.x,location.y);
        }
        counter++;
    }
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([touches count] < 2) {
        twoFingered = NO;
        NSLog(@"Two fingered no more");
    }
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
// This is called every vsync by CADisplayLink
- (void)drawRect:(CGRect)rect
{
    [self MSEngineTick];
}


@end
