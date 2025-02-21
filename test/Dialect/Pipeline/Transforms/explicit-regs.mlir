// RUN: circt-opt -pass-pipeline='builtin.module(hw.module(pipeline.scheduled(pipeline-explicit-regs)))' --allow-unregistered-dialect %s | FileCheck %s

// CHECK-LABEL:   hw.module @testRegsOnly(
// CHECK-SAME:            %[[VAL_0:.*]]: i32, %[[VAL_1:.*]]: i32, %[[VAL_2:.*]]: i1, %[[VAL_3:.*]]: i1, %[[VAL_4:.*]]: i1) -> (out0: i32, out1: i1) {
// CHECK:           %[[VAL_5:.*]], %[[VAL_6:.*]] = pipeline.scheduled(%[[VAL_0]], %[[VAL_1]]) clock %[[VAL_3]] reset %[[VAL_4]] go %[[VAL_2]] : (i32, i32) -> i32 {
// CHECK:           ^bb0(%[[VAL_7:.*]]: i32, %[[VAL_8:.*]]: i32, %[[VAL_9:.*]]: i1):
// CHECK:             %[[VAL_10:.*]] = comb.add %[[VAL_7]], %[[VAL_8]] : i32
// CHECK:             pipeline.stage ^bb1 regs(%[[VAL_10]] : i32, %[[VAL_7]] : i32)
// CHECK:           ^bb1(%[[VAL_11:.*]]: i32, %[[VAL_12:.*]]: i32, %[[VAL_13:.*]]: i1):
// CHECK:             %[[VAL_14:.*]] = comb.add %[[VAL_11]], %[[VAL_12]] : i32
// CHECK:             pipeline.stage ^bb2 regs(%[[VAL_14]] : i32, %[[VAL_11]] : i32)
// CHECK:           ^bb2(%[[VAL_15:.*]]: i32, %[[VAL_16:.*]]: i32, %[[VAL_17:.*]]: i1):
// CHECK:             %[[VAL_18:.*]] = comb.add %[[VAL_15]], %[[VAL_16]] : i32
// CHECK:             pipeline.return %[[VAL_18]] : i32
// CHECK:           }
// CHECK:           hw.output %[[VAL_19:.*]], %[[VAL_20:.*]] : i32, i1
// CHECK:         }

hw.module @testRegsOnly(%arg0 : i32, %arg1 : i32, %go : i1, %clk : i1, %rst : i1) -> (out0: i32, out1: i1) {
  %out:2 = pipeline.scheduled(%arg0, %arg1) clock %clk reset %rst go %go : (i32, i32) -> (i32) {
    ^bb0(%a0 : i32, %a1: i32, %g : i1):
      %add0 = comb.add %a0, %a1 : i32
      pipeline.stage ^bb1
    
    ^bb1(%s1_valid : i1):
      %add1 = comb.add %add0, %a0 : i32 // %a0 is a block argument fed through a stage.
      pipeline.stage ^bb2

    ^bb2(%s2_valid : i1):
      %add2 = comb.add %add1, %add0 : i32 // %add0 crosses multiple stages.
      pipeline.return %add2 : i32
  }
  hw.output %out#0, %out#1 : i32, i1
}

// CHECK-LABEL:   hw.module @testLatency1(
// CHECK-SAME:          %[[VAL_0:.*]]: i32, %[[VAL_1:.*]]: i32, %[[VAL_2:.*]]: i1, %[[VAL_3:.*]]: i1, %[[VAL_4:.*]]: i1) -> (out: i32) {
// CHECK:           %[[VAL_5:.*]], %[[VAL_6:.*]] = pipeline.scheduled(%[[VAL_0]]) clock %[[VAL_3]] reset %[[VAL_4]] go %[[VAL_2]] : (i32) -> i32 {
// CHECK:           ^bb0(%[[VAL_7:.*]]: i32, %[[VAL_8:.*]]: i1):
// CHECK:             %[[VAL_9:.*]] = hw.constant true
// CHECK:             %[[VAL_10:.*]] = pipeline.latency 2 -> (i32) {
// CHECK:               %[[VAL_11:.*]] = comb.add %[[VAL_7]], %[[VAL_7]] : i32
// CHECK:               pipeline.latency.return %[[VAL_11]] : i32
// CHECK:             }
// CHECK:             pipeline.stage ^bb1 pass(%[[VAL_12:.*]] : i32)
// CHECK:           ^bb1(%[[VAL_13:.*]]: i32, %[[VAL_14:.*]]: i1):
// CHECK:             pipeline.stage ^bb2 pass(%[[VAL_13]] : i32)
// CHECK:           ^bb2(%[[VAL_15:.*]]: i32, %[[VAL_16:.*]]: i1):
// CHECK:             pipeline.stage ^bb3 regs(%[[VAL_15]] : i32)
// CHECK:           ^bb3(%[[VAL_17:.*]]: i32, %[[VAL_18:.*]]: i1):
// CHECK:             pipeline.stage ^bb4 regs(%[[VAL_17]] : i32)
// CHECK:           ^bb4(%[[VAL_19:.*]]: i32, %[[VAL_20:.*]]: i1):
// CHECK:             pipeline.return %[[VAL_19]] : i32
// CHECK:           }
// CHECK:           hw.output %[[VAL_21:.*]] : i32
// CHECK:         }
hw.module @testLatency1(%arg0 : i32, %arg1 : i32, %go : i1, %clk : i1, %rst : i1) -> (out: i32) {
  %out:2 = pipeline.scheduled(%arg0) clock %clk reset %rst go %go : (i32) -> (i32) {
  ^bb0(%a0 : i32, %s0_valid : i1):
    %true = hw.constant true
    %out = pipeline.latency 2 -> (i32) {
      %r = comb.add %a0, %a0 : i32
      pipeline.latency.return %r : i32
    }
    pipeline.stage ^bb1
  ^bb1(%s1_valid : i1):
    pipeline.stage ^bb2
  ^bb2(%s2_valid : i1):
    pipeline.stage ^bb3
  ^bb3(%s3_valid : i1):
    pipeline.stage ^bb4
  ^bb4(%s4_valid : i1):
    pipeline.return %out : i32
  }
  hw.output %out#0 : i32
}

// CHECK-LABEL:   hw.module @testLatency2(
// CHECK-SAME:          %[[VAL_0:.*]]: i32, %[[VAL_1:.*]]: i32, %[[VAL_2:.*]]: i1, %[[VAL_3:.*]]: i1, %[[VAL_4:.*]]: i1) -> (out: i32) {
// CHECK:           %[[VAL_5:.*]], %[[VAL_6:.*]] = pipeline.scheduled(%[[VAL_0]]) clock %[[VAL_3]] reset %[[VAL_4]] go %[[VAL_2]] : (i32) -> i32 {
// CHECK:           ^bb0(%[[VAL_7:.*]]: i32, %[[VAL_8:.*]]: i1):
// CHECK:             %[[VAL_9:.*]] = hw.constant true
// CHECK:             %[[VAL_10:.*]] = pipeline.latency 1 -> (i32) {
// CHECK:               %[[VAL_11:.*]] = comb.add %[[VAL_7]], %[[VAL_7]] : i32
// CHECK:               pipeline.latency.return %[[VAL_11]] : i32
// CHECK:             }
// CHECK:             pipeline.stage ^bb1 pass(%[[VAL_12:.*]] : i32)
// CHECK:           ^bb1(%[[VAL_13:.*]]: i32, %[[VAL_14:.*]]: i1):
// CHECK:             pipeline.stage ^bb2 regs(%[[VAL_13]] : i32)
// CHECK:           ^bb2(%[[VAL_15:.*]]: i32, %[[VAL_16:.*]]: i1):
// CHECK:             %[[VAL_17:.*]] = pipeline.latency 2 -> (i32) {
// CHECK:               %[[VAL_18:.*]] = comb.sub %[[VAL_15]], %[[VAL_15]] : i32
// CHECK:               pipeline.latency.return %[[VAL_18]] : i32
// CHECK:             }
// CHECK:             pipeline.stage ^bb3 regs(%[[VAL_15]] : i32) pass(%[[VAL_19:.*]] : i32)
// CHECK:           ^bb3(%[[VAL_20:.*]]: i32, %[[VAL_21:.*]]: i32, %[[VAL_22:.*]]: i1):
// CHECK:             pipeline.stage ^bb4 regs(%[[VAL_20]] : i32) pass(%[[VAL_21]] : i32)
// CHECK:           ^bb4(%[[VAL_23:.*]]: i32, %[[VAL_24:.*]]: i32, %[[VAL_25:.*]]: i1):
// CHECK:             %[[VAL_26:.*]] = comb.add %[[VAL_23]], %[[VAL_24]] : i32
// CHECK:             pipeline.return %[[VAL_23]] : i32
// CHECK:           }
// CHECK:           hw.output %[[VAL_27:.*]] : i32
// CHECK:         }
hw.module @testLatency2(%arg0 : i32, %arg1 : i32, %go : i1, %clk : i1, %rst : i1) -> (out: i32) {
  %out:2 = pipeline.scheduled(%arg0) clock %clk reset %rst go %go : (i32) -> (i32) {
  ^bb0(%a0 : i32, %s0_valid : i1):
    %true = hw.constant true
    %out = pipeline.latency 1 -> (i32) {
      %r = comb.add %a0, %a0 : i32
      pipeline.latency.return %r : i32
    }
    pipeline.stage ^bb1
  ^bb1(%s1_valid : i1):
    pipeline.stage ^bb2
  ^bb2(%s2_valid : i1):
    %out2 = pipeline.latency 2 -> (i32) {
      %r = comb.sub %out, %out : i32
      pipeline.latency.return %r : i32
    }
    pipeline.stage ^bb3
  ^bb3(%s3_valid : i1):
    pipeline.stage ^bb4
  ^bb4(%s4_valid : i1):
    %res = comb.add %out, %out2 : i32
    pipeline.return %out : i32
  }
  hw.output %out#0 : i32
}

// CHECK-LABEL:   hw.module @testLatencyToLatency(
// CHECK-SAME:            %[[VAL_0:.*]]: i32, %[[VAL_1:.*]]: i32, %[[VAL_2:.*]]: i1, %[[VAL_3:.*]]: i1, %[[VAL_4:.*]]: i1) -> (out: i32) {
// CHECK:           %[[VAL_5:.*]], %[[VAL_6:.*]] = pipeline.scheduled(%[[VAL_0]]) clock %[[VAL_3]] reset %[[VAL_4]] go %[[VAL_2]] : (i32) -> i32 {
// CHECK:           ^bb0(%[[VAL_7:.*]]: i32, %[[VAL_8:.*]]: i1):
// CHECK:             %[[VAL_9:.*]] = hw.constant true
// CHECK:             %[[VAL_10:.*]] = pipeline.latency 2 -> (i32) {
// CHECK:               %[[VAL_11:.*]] = comb.add %[[VAL_7]], %[[VAL_7]] : i32
// CHECK:               pipeline.latency.return %[[VAL_11]] : i32
// CHECK:             }
// CHECK:             pipeline.stage ^bb1 pass(%[[VAL_12:.*]] : i32)
// CHECK:           ^bb1(%[[VAL_13:.*]]: i32, %[[VAL_14:.*]]: i1):
// CHECK:             pipeline.stage ^bb2 pass(%[[VAL_13]] : i32)
// CHECK:           ^bb2(%[[VAL_15:.*]]: i32, %[[VAL_16:.*]]: i1):
// CHECK:             %[[VAL_17:.*]] = pipeline.latency 2 -> (i32) {
// CHECK:               %[[VAL_18:.*]] = hw.constant 1 : i32
// CHECK:               %[[VAL_19:.*]] = comb.add %[[VAL_15]], %[[VAL_18]] : i32
// CHECK:               pipeline.latency.return %[[VAL_19]] : i32
// CHECK:             }
// CHECK:             pipeline.stage ^bb3 pass(%[[VAL_20:.*]] : i32)
// CHECK:           ^bb3(%[[VAL_21:.*]]: i32, %[[VAL_22:.*]]: i1):
// CHECK:             pipeline.stage ^bb4 pass(%[[VAL_21]] : i32)
// CHECK:           ^bb4(%[[VAL_23:.*]]: i32, %[[VAL_24:.*]]: i1):
// CHECK:             pipeline.return %[[VAL_23]] : i32
// CHECK:           }
// CHECK:           hw.output %[[VAL_25:.*]] : i32
// CHECK:         }
hw.module @testLatencyToLatency(%arg0: i32, %arg1: i32, %go: i1, %clk: i1, %rst: i1) -> (out: i32) {
  %0:2 = pipeline.scheduled(%arg0) clock %clk reset %rst go %go : (i32) -> i32 {
  ^bb0(%arg0_0: i32, %s0_valid : i1):
    %true = hw.constant true
    %1 = pipeline.latency 2 -> (i32) {
      %res = comb.add %arg0_0, %arg0_0 : i32
      pipeline.latency.return %res : i32
    }
    pipeline.stage ^bb1
  ^bb1(%s1_valid : i1):
    pipeline.stage ^bb2

  ^bb2(%s2_valid : i1):
    %2 = pipeline.latency 2 -> (i32) {
      %c1_i32 = hw.constant 1 : i32
      %res2 = comb.add %1, %c1_i32 : i32
      pipeline.latency.return %res2 : i32
    }
    pipeline.stage ^bb3

  ^bb3(%s3_valid : i1):
    pipeline.stage ^bb4

  ^bb4(%s4_valid : i1):
    pipeline.return %2 : i32
  }
  hw.output %0#0 : i32
}

// CHECK-LABEL:   hw.module @test_arbitrary_nesting(
// CHECK-SAME:           %[[VAL_0:.*]]: i32, %[[VAL_1:.*]]: i32, %[[VAL_2:.*]]: i1, %[[VAL_3:.*]]: i1, %[[VAL_4:.*]]: i1) -> (out: i32) {
// CHECK:           %[[VAL_5:.*]], %[[VAL_6:.*]] = pipeline.scheduled(%[[VAL_0]]) clock %[[VAL_3]] reset %[[VAL_4]] go %[[VAL_2]] : (i32) -> i32 {
// CHECK:           ^bb0(%[[VAL_7:.*]]: i32, %[[VAL_8:.*]]: i1):
// CHECK:             %[[VAL_9:.*]] = hw.constant true
// CHECK:             pipeline.stage ^bb1 regs(%[[VAL_7]] : i32)
// CHECK:           ^bb1(%[[VAL_10:.*]]: i32, %[[VAL_11:.*]]: i1):
// CHECK:             %[[VAL_12:.*]] = "foo.foo"(%[[VAL_10]]) : (i32) -> i32
// CHECK:             "foo.bar"() ({
// CHECK:               %[[VAL_13:.*]] = "foo.foo"(%[[VAL_10]]) : (i32) -> i32
// CHECK:               "foo.baz"() ({
// CHECK:               ^bb0(%[[VAL_14:.*]]: i32):
// CHECK:                 "foo.foobar"(%[[VAL_12]], %[[VAL_13]], %[[VAL_14]]) : (i32, i32, i32) -> ()
// CHECK:                 "foo.foobar"(%[[VAL_10]]) : (i32) -> ()
// CHECK:               }) : () -> ()
// CHECK:             }) : () -> ()
// CHECK:             pipeline.stage ^bb2 regs(%[[VAL_10]] : i32)
// CHECK:           ^bb2(%[[VAL_15:.*]]: i32, %[[VAL_16:.*]]: i1):
// CHECK:             pipeline.return %[[VAL_15]] : i32
// CHECK:           }
// CHECK:           hw.output %[[VAL_17:.*]] : i32
// CHECK:         }
hw.module @test_arbitrary_nesting(%arg0 : i32, %arg1 : i32, %go : i1, %clk : i1, %rst : i1) -> (out: i32) {
  %out:2 = pipeline.scheduled(%arg0) clock %clk reset %rst go %go : (i32) -> (i32) {
  ^bb0(%a0 : i32, %s0_valid : i1):
    %true = hw.constant true
    pipeline.stage ^bb1
  ^bb1(%s1_valid : i1):
    %foo = "foo.foo" (%a0) : (i32) -> (i32)
    "foo.bar" () ({
      ^bb0:
      %foo2 = "foo.foo" (%a0) : (i32) -> (i32)
      "foo.baz" () ({
        ^bb0(%innerArg0 : i32):
        // Reference all of the values defined above - none of these should
        // be registered.
        "foo.foobar" (%foo, %foo2, %innerArg0) : (i32, i32, i32) -> ()

        // Reference %a0 - this should be registered.
        "foo.foobar" (%a0) : (i32) -> ()
      }) : () -> ()
    }) : () -> ()

    pipeline.stage ^bb2
  ^bb2(%s2_valid : i1):
    pipeline.return %a0 : i32
  }
  hw.output %out#0 : i32
}

// CHECK-LABEL:   hw.module @testExtInput(
// CHECK-SAME:            %[[VAL_0:.*]]: i32, %[[VAL_1:.*]]: i32, %[[VAL_2:.*]]: i1, %[[VAL_3:.*]]: i1, %[[VAL_4:.*]]: i1) -> (out0: i32, out1: i32) {
// CHECK:           %[[VAL_5:.*]]:2, %[[VAL_6:.*]] = pipeline.scheduled(%[[VAL_0]]) ext(%[[VAL_1]] : i32) clock %[[VAL_3]] reset %[[VAL_4]] go %[[VAL_2]] : (i32) -> (i32, i32) {
// CHECK:           ^bb0(%[[VAL_7:.*]]: i32, %[[VAL_8:.*]]: i32, %[[VAL_9:.*]]: i1):
// CHECK:             %[[VAL_10:.*]] = hw.constant true
// CHECK:             %[[VAL_11:.*]] = comb.add %[[VAL_7]], %[[VAL_8]] : i32
// CHECK:             pipeline.stage ^bb1 regs(%[[VAL_11]] : i32)
// CHECK:           ^bb1(%[[VAL_12:.*]]: i32, %[[VAL_13:.*]]: i1):
// CHECK:             pipeline.return %[[VAL_12]], %[[VAL_8]] : i32, i32
// CHECK:           }
// CHECK:           hw.output %[[VAL_14:.*]]#0, %[[VAL_14]]#1 : i32, i32
// CHECK:         }
hw.module @testExtInput(%arg0 : i32, %ext1 : i32, %go : i1, %clk : i1, %rst : i1) -> (out0: i32, out1: i32) {
  %out:3 = pipeline.scheduled(%arg0) ext(%ext1 : i32) clock %clk reset %rst go %go: (i32) -> (i32, i32) {
    ^bb0(%a0 : i32, %e0: i32, %s0_valid : i1):
      %true = hw.constant true
      %add0 = comb.add %a0, %e0 : i32
      pipeline.stage ^bb1

    ^bb1(%s1_valid : i1):
      pipeline.return %add0, %e0 : i32, i32
  }
  hw.output %out#0, %out#1 : i32, i32
}
