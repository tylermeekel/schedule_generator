import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process
import gleam/http
import gleam/io
import gleam/json
import gleam/list
import mist
import wisp

pub fn main() {
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp.mist_handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

fn handle_request(req: wisp.Request) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)

  let classes_decoder = dynamic.list(decode_class)
  let classes_result = classes_decoder(json)
  case classes_result {
    Ok(classes) -> {
      let schedules = generate_schedules(classes)
      let schedules_json = json.array(schedules, encode_schedule)
      wisp.json_response(json.to_string_builder(schedules_json), 200)
    }
    Error(error) -> {
      io.debug(error)
      wisp.bad_request()
    }
  }
}

fn encode_schedule(schedule: Schedule) -> json.Json {
  json.object([#("options", json.array(schedule.options, encode_option))])
}

fn encode_option(option: Option) -> json.Json {
  json.object([
    #("option_code", json.string(option.option_code)),
    #("time_slots", json.array(option.time_slots, encode_time_slot)),
  ])
}

fn encode_time_slot(time_slot: TimeSlot) -> json.Json {
  json.object([
    #("day", json.string(string_from_day(time_slot.day))),
    #("start_seconds_into_day", json.int(time_slot.start_seconds_into_day)),
    #("end_seconds_into_day", json.int(time_slot.end_seconds_into_day)),
  ])
}

fn string_from_day(day: Day) -> String {
  case day {
    Monday -> "Monday"
    Tuesday -> "Tuesday"
    Wednesday -> "Wednesday"
    Thursday -> "Thursday"
    Friday -> "Friday"
    Saturday -> "Saturday"
    Sunday -> "Sunday"
  }
}

fn decode_class(json: Dynamic) -> Result(Class, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode2(
      Class,
      dynamic.field("class_name", dynamic.string),
      dynamic.field("class_options", dynamic.list(decode_option)),
    )
  decoder(json)
}

fn decode_option(json: Dynamic) -> Result(Option, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode2(
      Option,
      dynamic.field("option_code", dynamic.string),
      dynamic.field("time_slots", dynamic.list(decode_time_slot)),
    )
  decoder(json)
}

fn decode_time_slot(json: Dynamic) -> Result(TimeSlot, dynamic.DecodeErrors) {
  let decoder =
    dynamic.decode3(
      TimeSlot,
      dynamic.field("day", decode_day),
      dynamic.field("start_seconds_into_day", dynamic.int),
      dynamic.field("end_seconds_into_day", dynamic.int),
    )
  decoder(json)
}

fn decode_day(json: Dynamic) -> Result(Day, dynamic.DecodeErrors) {
  let string_result = dynamic.string(json)
  case string_result {
    Ok(string) -> {
      string_to_day(string)
    }
    Error(error) -> Error(error)
  }
}

fn string_to_day(string: String) -> Result(Day, dynamic.DecodeErrors) {
  case string {
    "Monday" -> Ok(Monday)
    "Tuesday" -> Ok(Tuesday)
    "Wednesday" -> Ok(Wednesday)
    "Thursday" -> Ok(Thursday)
    "Friday" -> Ok(Friday)
    "Saturday" -> Ok(Saturday)
    "Sunday" -> Ok(Sunday)
    _ ->
      Error([dynamic.DecodeError("A day of the week was expected", string, [])])
  }
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

fn generate_schedules_for_classes(
  proto_schedule: Schedule,
  classes: List(Class),
) -> List(Schedule) {
  case classes {
    [] -> [proto_schedule]
    [first, ..rest] -> {
      let map_option_func = generate_schedules_for_option(
        proto_schedule,
        _,
        rest,
      )
      list.map(first.class_options, map_option_func)
      |> list.flatten
    }
  }
}

fn generate_schedules_for_option(
  proto_schedule: Schedule,
  option: Option,
  other_classes: List(Class),
) -> List(Schedule) {
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
  bool.and(
    time_slot1.day == time_slot2.day,
    bool.or(
      bool.and(
        time_slot1.start_seconds_into_day >= time_slot2.start_seconds_into_day,
        time_slot1.start_seconds_into_day <= time_slot2.end_seconds_into_day,
      ),
      bool.and(
        time_slot1.end_seconds_into_day >= time_slot2.start_seconds_into_day,
        time_slot1.end_seconds_into_day <= time_slot2.end_seconds_into_day,
      ),
    ),
  )
}
