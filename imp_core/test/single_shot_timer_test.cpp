#include <gtest/gtest.h>

// system includes
#include <assert.h>
#include <cstdint>
#include <iostream>

#include <imp/core/timer.hpp>


TEST(IMPCoreTestSuite, singleShotTimerTest)
{
  imp::SingleShotTimer::TimePoint start_outer = imp::SingleShotTimer::Clock::now();
  imp::SingleShotTimer timer("unit test timer");
  imp::SingleShotTimer::TimePoint start_inner = imp::SingleShotTimer::Clock::now();

  for (int i=0; i<10000; ++i)
  {
    // idle
  }

  imp::SingleShotTimer::TimePoint end_inner = imp::SingleShotTimer::Clock::now();
  imp::SingleShotTimer::Milliseconds duration = timer.elapsedMs();
  imp::SingleShotTimer::TimePoint end_outer = imp::SingleShotTimer::Clock::now();

  imp::SingleShotTimer::Milliseconds duration_inner =
      std::chrono::duration_cast<imp::SingleShotTimer::Milliseconds>(
        end_inner - start_inner);
  imp::SingleShotTimer::Milliseconds duration_outer =
      std::chrono::duration_cast<imp::SingleShotTimer::Milliseconds>(
        end_outer - start_outer);

  ASSERT_LE(duration_inner.count(), duration.count());
  ASSERT_GE(duration_outer.count(), duration.count());
}
