# Car Type API Documentation

This document describes the API endpoints and functionality for car types in the "Твоя шина" application.

## Overview

Car types represent different categories of vehicles (sedan, SUV, crossover, etc.) that can be used when booking car services. Clients can specify a car type even if they don't specify a specific car when making a booking.

## API Endpoints

### GET /api/v1/car_types

Returns a list of all available car types.

**Response Example:**
```json
[
  {
    "id": 1,
    "name": "Sedan",
    "description": "A standard passenger car with a separate trunk",
    "is_active": true,
    "created_at": "2025-05-16T07:04:16.000Z",
    "updated_at": "2025-05-16T07:04:16.000Z"
  },
  {
    "id": 2,
    "name": "SUV",
    "description": "Sport Utility Vehicle, combines features of road-going passenger cars with off-road vehicles",
    "is_active": true,
    "created_at": "2025-05-16T07:04:16.000Z",
    "updated_at": "2025-05-16T07:04:16.000Z"
  }
]
```

### GET /api/v1/car_types/:id

Returns details of a specific car type.

**Response Example:**
```json
{
  "id": 1,
  "name": "Sedan",
  "description": "A standard passenger car with a separate trunk",
  "is_active": true,
  "created_at": "2025-05-16T07:04:16.000Z",
  "updated_at": "2025-05-16T07:04:16.000Z"
}
```

## Using Car Types in Bookings

When creating a booking, you can specify either a car_id (for a specific client car) or a car_type_id (for a generic car type).

### POST /api/v1/clients/:client_id/bookings

**Request Example with Car Type:**
```json
{
  "booking": {
    "service_point_id": 1,
    "car_type_id": 2,
    "booking_date": "2025-05-20",
    "start_time": "10:00",
    "end_time": "11:00",
    "notes": "Need SUV service"
  }
}
```

**Response Example:**
```json
{
  "id": 123,
  "booking_date": "2025-05-20",
  "start_time": "10:00",
  "end_time": "11:00",
  "status": {
    "id": 1,
    "name": "pending",
    "color": "#FFC107"
  },
  "payment_status": null,
  "cancellation_reason": null,
  "cancellation_comment": null,
  "total_price": null,
  "payment_method": null,
  "notes": "Need SUV service",
  "car_type": {
    "id": 2,
    "name": "SUV",
    "description": "Sport Utility Vehicle, combines features of road-going passenger cars with off-road vehicles"
  },
  "client": {
    "id": 45,
    "first_name": "John",
    "last_name": "Doe"
  },
  "service_point": {
    "id": 1,
    "name": "Downtown Service Center"
  },
  "car": null,
  "booking_services": []
}
```
