const defaultScheduleJson = r'''
{
    "version": "2026.03.27",
    "operator": {
        "id": "bangladesh-railway",
        "name": "Bangladesh Railway"
    },
    "route": {
        "id": "bd-dhk-ngj-commuter",
        "code": "bd-dhk-ngj-commuter",
        "effectiveDate": "2025-03-10",
        "serviceDaysMask": 95,
        "serviceDaysLabel": "Saturday to Thursday",
        "sourceOfficiality": "high_confidence_image_source"
    },
    "stations": [
        {
            "id": "dhaka",
            "code": "dhaka",
            "name": "Dhaka"
        },
        {
            "id": "gendaria",
            "code": "gendaria",
            "name": "Gendaria"
        },
        {
            "id": "shyampur",
            "code": "shyampur",
            "name": "Shyampur"
        },
        {
            "id": "pagla",
            "code": "pagla",
            "name": "Pagla"
        },
        {
            "id": "fatullah",
            "code": "fatullah",
            "name": "Fatullah"
        },
        {
            "id": "chashara",
            "code": "chashara",
            "name": "Chashara"
        },
        {
            "id": "narayanganj",
            "code": "narayanganj",
            "name": "Narayanganj"
        }
    ],
    "directions": [
        {
            "id": "dhaka_to_narayanganj",
            "directionKey": "dhaka_to_narayanganj",
            "prefix": "dhk-ngj",
            "label": "Dhaka to Narayanganj",
            "isForward": true
        },
        {
            "id": "narayanganj_to_dhaka",
            "directionKey": "narayanganj_to_dhaka",
            "prefix": "ngj-dhk",
            "label": "Narayanganj to Dhaka",
            "isForward": false
        }
    ],
    "tripsByDirection": {
        "dhaka_to_narayanganj": [
            {
                "trainNo": 2,
                "servicePeriod": "early_morning",
                "stopTimes": [
                    "04:30",
                    "04:39",
                    "04:46",
                    "04:53",
                    "05:00",
                    "05:09",
                    "05:15"
                ]
            },
            {
                "trainNo": 4,
                "servicePeriod": "morning",
                "stopTimes": [
                    "06:55",
                    "07:04",
                    "07:11",
                    "07:18",
                    "07:25",
                    "07:34",
                    "07:40"
                ]
            },
            {
                "trainNo": 6,
                "servicePeriod": "morning",
                "stopTimes": [
                    "09:15",
                    "09:24",
                    "09:31",
                    "09:38",
                    "09:45",
                    "09:54",
                    "10:00"
                ]
            },
            {
                "trainNo": 8,
                "servicePeriod": "midday",
                "stopTimes": [
                    "12:25",
                    "12:29",
                    "12:36",
                    "12:43",
                    "12:50",
                    "12:59",
                    "13:05"
                ]
            },
            {
                "trainNo": 10,
                "servicePeriod": "afternoon",
                "stopTimes": [
                    "14:45",
                    "14:54",
                    "15:01",
                    "15:08",
                    "15:15",
                    "15:24",
                    "15:30"
                ]
            },
            {
                "trainNo": 12,
                "servicePeriod": "evening",
                "stopTimes": [
                    "17:05",
                    "17:14",
                    "17:21",
                    "17:28",
                    "17:35",
                    "17:44",
                    "17:50"
                ]
            },
            {
                "trainNo": 14,
                "servicePeriod": "evening",
                "stopTimes": [
                    "19:35",
                    "19:44",
                    "19:51",
                    "19:58",
                    "20:05",
                    "20:14",
                    "20:20"
                ]
            },
            {
                "trainNo": 16,
                "servicePeriod": "night",
                "stopTimes": [
                    "21:55",
                    "22:04",
                    "22:11",
                    "22:18",
                    "22:25",
                    "22:34",
                    "22:40"
                ]
            }
        ],
        "narayanganj_to_dhaka": [
            {
                "trainNo": 1,
                "servicePeriod": "early_morning",
                "stopTimes": [
                    "05:45",
                    "05:52",
                    "06:00",
                    "06:07",
                    "06:14",
                    "06:22",
                    "06:30"
                ]
            },
            {
                "trainNo": 3,
                "servicePeriod": "morning",
                "stopTimes": [
                    "08:00",
                    "08:07",
                    "08:16",
                    "08:23",
                    "08:30",
                    "08:38",
                    "08:46"
                ]
            },
            {
                "trainNo": 5,
                "servicePeriod": "morning",
                "stopTimes": [
                    "10:25",
                    "10:37",
                    "10:45",
                    "10:51",
                    "10:58",
                    "11:05",
                    "11:13"
                ]
            },
            {
                "trainNo": 7,
                "servicePeriod": "midday",
                "stopTimes": [
                    "13:05",
                    "13:42",
                    "13:50",
                    "13:57",
                    "14:04",
                    "14:11",
                    "14:19"
                ]
            },
            {
                "trainNo": 9,
                "servicePeriod": "afternoon",
                "stopTimes": [
                    "15:55",
                    "16:02",
                    "16:10",
                    "16:17",
                    "16:24",
                    "16:32",
                    "16:40"
                ]
            },
            {
                "trainNo": 11,
                "servicePeriod": "evening",
                "stopTimes": [
                    "18:20",
                    "18:27",
                    "18:35",
                    "18:42",
                    "18:49",
                    "18:56",
                    "19:05"
                ]
            },
            {
                "trainNo": 13,
                "servicePeriod": "night",
                "stopTimes": [
                    "20:45",
                    "20:52",
                    "21:00",
                    "21:07",
                    "21:14",
                    "21:21",
                    "21:30"
                ]
            },
            {
                "trainNo": 15,
                "servicePeriod": "late_night",
                "stopTimes": [
                    "23:05",
                    "23:12",
                    "23:20",
                    "23:27",
                    "23:34",
                    "23:41",
                    "23:50"
                ]
            }
        ]
    }
}
''';
