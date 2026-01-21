package com.flowlog.sync;

import akka.actor.typed.ActorSystem;
import akka.actor.typed.Behavior;
import akka.actor.typed.javadsl.Behaviors;

public class SyncServerApplication {
    public static void main(String[] args) {
        ActorSystem<Void> system = ActorSystem.create(rootBehavior(), "SyncServer");
    }

    private static Behavior<Void> rootBehavior() {
        return Behaviors.setup(context -> {
            context.getLog().info("Sync Server started");
            return Behaviors.empty();
        });
    }
}
