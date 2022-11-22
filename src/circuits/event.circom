pragma circom 2.0.3;

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/gates.circom";
include "../node_modules/circomlib/circuits/mux1.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";

/* 
    Sequentially hash a player event. 
*/
template EventHash(D) {
    signal input step_in;           // The sequential hash of each previous event 
    signal output step_out;         // The sequential hash of each previous event, plus this event
    
    signal input frame;             // The frame that this event took place in
    signal input player;           // The player that logged this event
    signal input unit;              // The selected unit for this event
    signal input vector[D];         // The new movement vector for the selected unit for this event

    component hash = Poseidon(4+D);
    hash.inputs[0] <== step_in;
    hash.inputs[1] <== frame;
    hash.inputs[2] <== player;
    hash.inputs[3] <== unit;
    for (var i=0; i < D; i++) { 
        hash.inputs[4+i] <== vector[i];
    }

    step_out <== hash.out;
}

/* 
    Update the movement vectors for each frame of the game, for each unit, after applying a player event.
    The event is ignored if it does not take place within a game frame or the player does not own the unit.
 */
template EventVector(T, N, D) {
    signal input step_in[T][N][D];      // The vectors per frame, per unit, before applying this event
    signal output step_out[T][N][D];    // The vectors per frame, per unit, after applying this event
    
    signal input frame;                 // The frame that this event took place in
    signal input player;                // The player that logged this event
    signal input unit;                  // The selected unit for this event
    signal input vector[D];             // The new movement vector for the selected unit for this event

    signal eventFound[T][N];

    component isFrame[T];               // Whether each frame corresponds to this events frame
    component isPlayer[N];              // Whether each unit is owned by this events player
    component isUnit[T][N];             // Whether each unit was selected this frame
    component isFrameANDisUnitANDisAccount[T][N];
    component isFrameANDisUnitANDisAccountOReventFound[T][N];
    component mux[T][N];

    // Player's 0 and 1 get half of the units each. All other player ID's are ignored.
    for (var i=0; i < N; i++) { 
        isPlayer[i] = IsEqual();
        isPlayer[i].in[0] <== player;
        isPlayer[i].in[1] <== i < (N / 2);
    }

    // Find the frame and unit that correspond to this event (if any, users can submit invalid data)
    // If found, update this units target position for this frame and all subsequent frames.
    for (var i=0; i < T; i++) {
        isFrame[i] = IsEqual();
        isFrame[i].in[0] <== i;
        isFrame[i].in[1] <== frame;

        for (var j=0; j < N; j++) { 
            isUnit[i][j] = IsEqual();
            isUnit[i][j].in[0] <== j;
            isUnit[i][j].in[1] <== unit;

            isFrameANDisUnitANDisAccount[i][j] = MultiAND(3);
            isFrameANDisUnitANDisAccount[i][j].in[0] <== isFrame[i].out;
            isFrameANDisUnitANDisAccount[i][j].in[1] <== isUnit[i][j].out;
            isFrameANDisUnitANDisAccount[i][j].in[2] <== isPlayer[j].out;

            isFrameANDisUnitANDisAccountOReventFound[i][j] = OR();
            isFrameANDisUnitANDisAccountOReventFound[i][j].a <== isFrameANDisUnitANDisAccount[i][j].out;
            isFrameANDisUnitANDisAccountOReventFound[i][j].b <== i == 0 ? 0 : eventFound[i-1][j];

            eventFound[i][j] <== (i==0 ? 0 : eventFound[i-1][j]) + isFrameANDisUnitANDisAccount[i][j].out;
            
            mux[i][j] = MultiMux1(D);
            mux[i][j].s <== isFrameANDisUnitANDisAccountOReventFound[i][j].out;
            for (var k=0; k < D; k++) {
                mux[i][j].c[k][0] <== step_in[i][j][k];
                mux[i][j].c[k][1] <== vector[k];
            }

            step_out[i][j] <== mux[i][j].out;
        }
    }
}

/* 
    Hash an event.
*/
template Event(nFrames, nUnits, nDims) {
    signal input step_in;

    signal input frame;
    signal input player;
    signal input unit;
    signal input vector[nDims];

    component hash = EventHash(nDims);
    hash.frame <== frame;
    hash.player <== player;
    hash.unit <== unit;
    hash.vector <== vector;
}

component main { public [step_in] } = EventVector(600, 10, 2);