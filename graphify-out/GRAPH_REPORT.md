# Graph Report - /Users/sambhar/Desktop/experthub-api  (2026-07-08)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 797 nodes · 911 edges · 145 communities (61 shown, 84 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49
- Community 50
- Community 51
- Community 52
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 61
- Community 62
- Community 63
- Community 64
- Community 65
- Community 66
- Community 67
- Community 68
- Community 69
- Community 70
- Community 71
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 80
- Community 81
- Community 82
- Community 83
- Community 84
- Community 85
- Community 86
- Community 87
- Community 88
- Community 89
- Community 90
- Community 91
- Community 92
- Community 93
- Community 94
- Community 95
- Community 96
- Community 97
- Community 98
- Community 99
- Community 100
- Community 101
- Community 102
- Community 103
- Community 104
- Community 105
- Community 106

## God Nodes (most connected - your core abstractions)
1. `ApplicationController` - 52 edges
2. `ApplicationRecord` - 48 edges
3. `Booking` - 31 edges
4. `BookingsController` - 21 edges
5. `User` - 21 edges
6. `Tenant` - 17 edges
7. `seed_tenant()` - 14 edges
8. `ExpertProfile` - 13 edges
9. `RescheduleRequest` - 12 edges
10. `ApplicationJob` - 11 edges

## Surprising Connections (you probably didn't know these)
- `seed_tenant()` --calls--> `Booking`  [EXTRACTED]
  db/seeds.rb → app/models/booking.rb
- `seed_tenant()` --calls--> `Category`  [EXTRACTED]
  db/seeds.rb → app/models/category.rb
- `seed_tenant()` --calls--> `Enrollment`  [EXTRACTED]
  db/seeds.rb → app/models/enrollment.rb
- `seed_tenant()` --calls--> `ExpertProfile`  [EXTRACTED]
  db/seeds.rb → app/models/expert_profile.rb
- `seed_tenant()` --calls--> `GroupSession`  [EXTRACTED]
  db/seeds.rb → app/models/group_session.rb

## Import Cycles
- None detected.

## Communities (145 total, 84 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.07
Nodes (9): ConversationsController, ReferralsController, ReviewsController, Users::SessionsController, Conversation, Review, User, find_or_create_demo_user() (+1 more)

### Community 1 - "Community 1"
Cohesion: 0.07
Nodes (9): ExpertProfileBlueprint, Base, Base, UserBlueprint, ExpertsController, UsersController, StandardError, StripeError (+1 more)

### Community 2 - "Community 2"
Cohesion: 0.07
Nodes (12): Admin::ExpertApplicationsController, Ai, MatchController, GenerateEmbeddingJob, ApplicationMailer, Base, ExpertMailer, ExpertEmbedding (+4 more)

### Community 3 - "Community 3"
Cohesion: 0.10
Nodes (9): BookingBlueprint, Base, BookingsController, BookingEndedJob, SessionSummary, Ai, extract_action_items(), fetch_summary_and_action_items() (+1 more)

### Community 4 - "Community 4"
Cohesion: 0.07
Nodes (7): ApplicationCable, Connection, Base, BillingController, PlanFeatures, Tenant, PlatformBillingService

### Community 5 - "Community 5"
Cohesion: 0.09
Nodes (5): TenantsController, Users::RegistrationsController, Membership, TenantSetupService, RegistrationsController

### Community 6 - "Community 6"
Cohesion: 0.08
Nodes (13): ApplicationRecord, Base, BlockedDate, BookingPackage, CheckoutField, CheckoutFieldValue, ExpertApplication, LessonQuiz (+5 more)

### Community 7 - "Community 7"
Cohesion: 0.10
Nodes (7): ApplicationCable, Channel, Base, ConversationChannel, NotificationChannel, Message, Notification

### Community 8 - "Community 8"
Cohesion: 0.14
Nodes (4): API, ApplicationController, Current, CurrentAttributes

### Community 9 - "Community 9"
Cohesion: 0.22
Nodes (4): WebhooksController, StandardError, WebhookError, WebhookService

### Community 12 - "Community 12"
Cohesion: 0.15
Nodes (5): ReferralCredit, PayfastError, PayfastService, StandardError, ReferralService

### Community 13 - "Community 13"
Cohesion: 0.19
Nodes (7): Ai, TriageController, AiTriageSession, Ai, extract_recommendations(), get_chatbot_reply(), TriageChatService

### Community 16 - "Community 16"
Cohesion: 0.21
Nodes (7): ApplicationJob, Base, NewBookingNotificationJob, SendBookingReceiptJob, SendWebhookJob, enqueue_free_booking_jobs(), enqueue_paid_booking_jobs()

### Community 17 - "Community 17"
Cohesion: 0.21
Nodes (7): ConfirmBookingJob, BookingError, BookingService, PaymentFailed, StandardError, slot_available?(), SlotUnavailable

### Community 18 - "Community 18"
Cohesion: 0.17
Nodes (4): Course, Service, WorkingTimeSlot, seed_tenant()

### Community 19 - "Community 19"
Cohesion: 0.18
Nodes (4): CreateVideoRoomJob, DailyError, DailyService, StandardError

### Community 20 - "Community 20"
Cohesion: 0.24
Nodes (3): CategoryBlueprint, Base, CategoriesController

### Community 21 - "Community 21"
Cohesion: 0.24
Nodes (3): Base, ServiceBlueprint, ServicesController

### Community 23 - "Community 23"
Cohesion: 0.27
Nodes (6): handle_payment_captured(), handle_payment_failed(), RazorpayError, RazorpayService, StandardError, verify_signature!()

### Community 25 - "Community 25"
Cohesion: 0.25
Nodes (3): Category, Localizable, Page

### Community 41 - "Community 41"
Cohesion: 0.40
Nodes (3): PaypalError, PaypalService, StandardError

### Community 42 - "Community 42"
Cohesion: 0.40
Nodes (4): build-frontend.sh script, VITE_API_URL, VITE_APP_DOMAIN, VITE_CABLE_URL

## Knowledge Gaps
- **18 isolated node(s):** `ApplicationCable`, `ApplicationCable`, `Ai`, `Ai`, `Ai` (+13 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **84 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ApplicationController` connect `Community 8` to `Community 35`, `Community 4`, `Community 5`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Why does `Tenant` connect `Community 4` to `Community 6`?**
  _High betweenness centrality (0.002) - this node is a cross-community bridge._
- **Why does `Booking` connect `Community 14` to `Community 46`, `Community 6`?**
  _High betweenness centrality (0.001) - this node is a cross-community bridge._
- **What connects `ApplicationCable`, `ApplicationCable`, `Ai` to the rest of the system?**
  _18 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06507936507936508 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.07394957983193277 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.06722689075630252 - nodes in this community are weakly interconnected._