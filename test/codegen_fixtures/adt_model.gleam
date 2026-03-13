// Test file for ADT prism generation

import gleam/option

pub type Shape {
  Circle(radius: Float)
  Rectangle(width: Float, height: Float)
  Square(side: Float)
  Point
}

pub type Result(a, e) {
  Ok(a)
  Error(e)
}

pub type User {
  User(name: String, email: option.Option(String), age: Int)
}
