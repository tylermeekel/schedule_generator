import gleam/io
import gleam/bool
import gleam/list

pub fn main() {
  let classes = [
    Class("A", [
      Option("A1", [TimeSlot(Monday, 400, 500), TimeSlot(Tuesday, 400, 500)]),
      Option("A2", [TimeSlot(Wednesday, 400, 500), TimeSlot(Friday, 400, 500)]),
      Option("A3", [TimeSlot(Monday, 400, 500), TimeSlot(Wednesday, 400, 500)]),
      Option("A4", [TimeSlot(Tuesday, 400, 500), TimeSlot(Thursday, 400, 500)]),
      Option("A5", [TimeSlot(Friday, 400, 500), TimeSlot(Saturday, 400, 500)]),
      Option("A6", [TimeSlot(Monday, 400, 500), TimeSlot(Saturday, 400, 500)]),
    ]),
    Class("B", [
      Option("B1", [TimeSlot(Monday, 400, 500), TimeSlot(Tuesday, 400, 500)]),
      Option("B2", [TimeSlot(Wednesday, 400, 500), TimeSlot(Friday, 400, 500)]),
      Option("B3", [TimeSlot(Monday, 400, 500), TimeSlot(Wednesday, 400, 500)]),
      Option("B4", [TimeSlot(Tuesday, 400, 500), TimeSlot(Thursday, 400, 500)]),
      Option("B5", [TimeSlot(Friday, 400, 500), TimeSlot(Saturday, 400, 500)]),
      Option("B6", [TimeSlot(Monday, 400, 500), TimeSlot(Saturday, 400, 500)]),
    ]),
    Class("C", [
      Option("C1", [TimeSlot(Sunday, 200, 300)])
    ])
  ]

  let schedules = generate_schedules(classes)

  io.debug(schedules)
}

pub type Day {
  Monday
  Tuesday
  Wednesday
  Thursday
  Friday
  Saturday
  Sunday
}

pub type TimeSlot {
  TimeSlot(day: Day, start_seconds_into_day: Int, end_seconds_into_day: Int)
}

pub type Option {
  Option(option_code: String, time_slots: List(TimeSlot))
}

pub type Class {
  Class(class_name: String, class_options: List(Option))
}

pub type Schedule {
  Schedule(options: List(Option))
}

pub fn generate_schedules(classes: List(Class)) -> List(Schedule) {
  let proto_schedule = Schedule([])
  generate_schedules_for_classes(proto_schedule, classes)
}

fn generate_schedules_for_classes(proto_schedule: Schedule, classes: List(Class)) -> List(Schedule) {
  case classes {
    [] -> [proto_schedule]
    [first, ..rest] -> {
      let map_option_func = generate_schedules_for_option(proto_schedule, _, rest)
      list.map(first.class_options, map_option_func)
      |> list.flatten
    }
  }
}

fn generate_schedules_for_option(proto_schedule: Schedule, option: Option, other_classes: List(Class)) -> List(Schedule) {
  case check_fits_in_schedule(option, proto_schedule) {
    True -> {
      let new_schedule = Schedule([option, ..proto_schedule.options])
      generate_schedules_for_classes(new_schedule, other_classes)
    }
    False -> []
  }
}

fn check_fits_in_schedule(option: Option, schedule: Schedule) -> Bool {
  let overlap_with_option = check_option_overlap(option, _)
  bool.negate(list.any(schedule.options, overlap_with_option))
}

fn check_option_overlap(option1: Option, option2: Option) -> Bool {
  let overlap_with_time_slot = check_option_time_slot_overlap(option1, _)
  list.any(option2.time_slots, overlap_with_time_slot)
}

fn check_option_time_slot_overlap(option: Option, time_slot: TimeSlot) -> Bool {
  let overlap_with_time_slot = check_time_slot_overlap(time_slot, _)
  list.any(option.time_slots, overlap_with_time_slot)
}

fn check_time_slot_overlap(time_slot1: TimeSlot, time_slot2: TimeSlot) -> Bool {
  bool.and(time_slot1.day == time_slot2.day, bool.or(
    bool.and(time_slot1.start_seconds_into_day >= time_slot2.start_seconds_into_day, time_slot1.start_seconds_into_day <= time_slot2.end_seconds_into_day),
    bool.and(time_slot1.end_seconds_into_day >= time_slot2.start_seconds_into_day, time_slot1.end_seconds_into_day <= time_slot2.end_seconds_into_day) 
  ))
}