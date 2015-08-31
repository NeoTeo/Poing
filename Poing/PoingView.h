//
//  PoingView.h
//  Poing
//
//  Created by Matteo Sartori on 01/03/12.
//  Copyright (c) 2012 I Love You Bits. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef struct
{
    float x;
    float y;
    float z;
} Vector3;

typedef struct {
    int particleAIndex;
    int particleBIndex;
    float restLength;
} Constraint;

#define MAX_LEN 400//600
#define NUM_PARTICLES 192//48
#define NUM_ITERATIONS 16//4 // The higher the NUM_PARTICLES the higher the NUM_ITERATIONS needs to be
#define NUM_CONSTRAINTS NUM_PARTICLES-1

@interface PoingView : UIView
{
    //NSMutableArray *pointArray;
    // The positions the user decides by touching the display.
    Vector3 userPosition1,userPosition2;
    Vector3 *currentPositions;
    Vector3 previousPositions[NUM_PARTICLES];
    Vector3 forceAccumulators[NUM_PARTICLES];
    Vector3 gravity;
    float   timeStep;
    
    // Holds all particles in the system and will be the combination of the elastic and the ball.
    Vector3 *allParticlesPosArray;
    // The current positions of the elastic particles.
    Vector3 *elasticParticlesPosArray; // replaces currentPositons
    // The previous positions of the elastic particles.
    Vector3 *prevElasticParticlesPosArray;
    
    // The ball
    Vector3 ballPos;
    Vector3 ballPrevPos;
    Vector3 ballForce;
    Constraint ballConstraint;
    
    Constraint constraints[NUM_CONSTRAINTS];
    BOOL twoFingered;
}

@property (nonatomic, strong) CADisplayLink *displayLink;
- (void)vmin:(Vector3 *)a  against:(Vector3 *)b into:(Vector3 *)c;
- (void)vmax:(Vector3 *)a  against:(Vector3 *)b into:(Vector3 *)c;

@end
