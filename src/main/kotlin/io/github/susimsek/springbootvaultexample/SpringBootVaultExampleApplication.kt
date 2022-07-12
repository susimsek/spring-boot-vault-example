package io.github.susimsek.springbootvaultexample

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.cloud.client.discovery.EnableDiscoveryClient

@SpringBootApplication
@EnableDiscoveryClient
class SpringBootVaultExampleApplication

fun main(args: Array<String>) {
    runApplication<SpringBootVaultExampleApplication>(*args)
}
