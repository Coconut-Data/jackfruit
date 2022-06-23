Encryptor = require('simple-encryptor')

gatewayDetails  = {
  Tusome22340: 
    password: "emosuttusome"
    data: [
      'us-east-1:795599f2-be2c-489d-9466-5f8370298f6b'
    ]
}

encryptedObject = {}
for gatewayName, gatewayDetail of gatewayDetails
  if gatewayDetail.password
    passwordForEncryption = gatewayDetail.password+gatewayDetail.password+gatewayDetail.password
    encryptedObject[gatewayName] =
      data: Encryptor(passwordForEncryption).encrypt(gatewayDetail.data)
  else
    encryptedObject[gatewayName] = gatewayDetail

console.log encryptedObject

