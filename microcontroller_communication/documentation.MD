####-- MICROCONTROLLER COMMUNICATION --

A thingy to make communicating with other microcontrollers easier.

Communication.SendMessage(topicName: string, port: (number or port object), dataToSend: any)
returns: Communication.MessageResult

    Requires a disk to be connected on the provided port.

    Communication.MessageResult
        .Results: Table of all results that were returned by topic subscriptions
        
        :WaitForResult(index: any, timeoutSeconds: number)
            Waits the amount of seconds for the index to be added to the .Results table.
            

Communication.SendMessage(topicName: string, port: (number or port object), callbackFunction: function)
returns: Communication.TopicSubscription

    Communication.TopicSubscription
        .TopicName: Name of the topic the subscription is subscribed to.
        
        :Unbind(): Unbinds the topic subscription from the callback.
        
        :SendReturnMessage(topicName: string, dataToSend: any)
            Sends a message using the disk of the latest sender. Can allow messages to be sent along the network without the specific
            microcontroller having a disk of it's own.
