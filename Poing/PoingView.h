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

#define NUM_PARTICLES 12
#define NUM_ITERATIONS 1
#define NUM_CONSTRAINTS NUM_PARTICLES-1

@interface PoingView : UIView
{
    //NSMutableArray *pointArray;
    Vector3 userPosition;
    Vector3 *currentPositions;
    Vector3 previousPositions[NUM_PARTICLES];
    Vector3 forceAccumulators[NUM_PARTICLES];
    Vector3 gravity;
    float   timeStep;
    
    Constraint constraints[NUM_CONSTRAINTS];
}

@property (nonatomic, strong) CADisplayLink *displayLink;


@end
