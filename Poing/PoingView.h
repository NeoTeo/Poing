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

#define NUM_PARTICLES 3
#define NUM_ITERATIONS 2

@interface PoingView : UIView
{
    //NSMutableArray *pointArray;
    Vector3 userPosition;
    Vector3 *currentPositions;
    Vector3 previousPositions[NUM_PARTICLES];
    Vector3 forceAccumulators[NUM_PARTICLES];
    Vector3 gravity;
    float   timeStep;
}

@property (nonatomic, strong) CADisplayLink *displayLink;


@end
