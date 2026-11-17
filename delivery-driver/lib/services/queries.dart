class Queries {
  static const String login = """
    mutation Login(\$email: String!, \$password: String!) {
      login(email: \$email, password: \$password) {
        token
        user {
          id
          firstName
          lastName
          userType
          driverProfile {
            status
            isOnline
          }
        }
      }
    }
  """;

  static const String registerDriver = """
    mutation RegisterDriver(\$vehicleType: String!, \$plateNumber: String!, \$licenseNumber: String!) {
      registerDriver(vehicleType: \$vehicleType, plateNumber: \$plateNumber, licenseNumber: \$licenseNumber) {
        id
        userType
        driverProfile {
          status
        }
      }
    }
  """;

  static const String toggleDriverStatus = """
    mutation ToggleDriverStatus(\$isOnline: Boolean!) {
      toggleDriverStatus(isOnline: \$isOnline) {
        id
        driverProfile {
          isOnline
        }
      }
    }
  """;

  static const String updateDriverLocation = """
    mutation UpdateDriverLocation(\$lat: Float!, \$lon: Float!) {
      updateDriverLocation(lat: \$lat, lon: \$lon) {
        id
      }
    }
  """;

  static const String orderDispatch = """
    subscription OrderDispatch(\$lat: Float!, \$lon: Float!, \$radius: Int) {
      orderDispatch(lat: \$lat, lon: \$lon, radius: \$radius) {
        id
        status
        deliveryFee
        restaurantId
        branchId
        pickupLocation {
            lat
            lon
        }
        deliveryAddress {
            address
            lat
            lon
        }
        items {
          name
          quantity
        }
      }
    }
  """;
  
  static const String acceptOrder = """
    mutation AcceptOrder(\$orderId: ID!) {
      acceptOrder(orderId: \$orderId) {
        id
        status
      }
    }
  """;

  static const String updateDriverPushToken = """
    mutation UpdateDriverPushToken(\$token: String!) {
      updateDriverPushToken(token: \$token) {
        id
        driverProfile {
          fcmToken
        }
      }
    }
  """;

  static const String registerDriverAuth = """
    mutation RegisterDriverAuth(
      \$firstName: String!
      \$lastName: String!
      \$email: String!
      \$password: String!
      \$phoneNr: String
      \$vehicleType: String!
      \$plateNumber: String!
      \$licenseNumber: String!
    ) {
      registerDriverAuth(
        firstName: \$firstName
        lastName: \$lastName
        email: \$email
        password: \$password
        phoneNr: \$phoneNr
        vehicleType: \$vehicleType
        plateNumber: \$plateNumber
        licenseNumber: \$licenseNumber
      ) {
        id
        email
        firstName
        lastName
        userType
        accountConfirmed
      }
    }
  """;

  static const String getAvailableOrders = """
    query GetAvailableOrders(\$lat: Float!, \$lon: Float!, \$radius: Int) {
      getAvailableOrders(lat: \$lat, lon: \$lon, radius: \$radius) {
        id
        status
        deliveryFee
        restaurantId
        branchId
        pickupLocation {
           lat
           lon
        }
        deliveryAddress {
           address
           lat
           lon
        }
        items {
          name
          quantity
        }
      }
    }
  """;
  static const String getNearbyBranches = """
    query GetNearbyBranches(\$lat: Float!, \$lon: Float!, \$radius: Int) {
      getNearbyBranches(lat: \$lat, lon: \$lon, radius: \$radius) {
        branch {
          id
          name
          location {
            lat
            lon
          }
        }
        restaurant {
           name
        }
        activeOrdersCount
        activeOrders {
          id
          status
          deliveryFee
          items {
             name
             quantity
          }
          deliveryMethod
          pickupLocation {
            lat
            lon
          }
          deliveryAddress {
            address
            lat
            lon
          }
          contactInfo {
            firstName
            lastName
            phoneNr
          }
          items {
            name
            quantity
          }
        }
      }
    }
  """;
}
