#!/bin/bash
set -e

echo "→ Removing old services..."
rm -rf services/form-service
rm -rf services/submission-service

echo "→ Creating new services..."
mkdir -p services/document-service
mkdir -p services/classifier-service
mkdir -p services/extraction-service
mkdir -p services/guidance-service

touch services/document-service/.gitkeep
touch services/classifier-service/.gitkeep
touch services/extraction-service/.gitkeep
touch services/guidance-service/.gitkeep

echo "→ Rewriting parent pom.xml..."
cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.astraform</groupId>
    <artifactId>astraform</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <packaging>pom</packaging>
    <name>AstraForm Platform</name>
    <description>AI-powered document processing and form filling assistant</description>

    <modules>
        <module>shared/astraform-commons</module>
        <module>services/api-gateway</module>
        <module>services/auth-service</module>
        <module>services/document-service</module>
        <module>services/classifier-service</module>
        <module>services/extraction-service</module>
        <module>services/guidance-service</module>
        <module>services/notification-service</module>
        <module>services/analytics-service</module>
        <module>services/billing-service</module>
    </modules>

    <properties>
        <java.version>21</java.version>
        <maven.compiler.source>21</maven.compiler.source>
        <maven.compiler.target>21</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <spring-boot.version>3.3.0</spring-boot.version>
        <spring-cloud.version>2023.0.1</spring-cloud.version>
        <spring-ai.version>1.0.0</spring-ai.version>
    </properties>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>${spring-boot.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>org.springframework.cloud</groupId>
                <artifactId>spring-cloud-dependencies</artifactId>
                <version>${spring-cloud.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>org.springframework.ai</groupId>
                <artifactId>spring-ai-bom</artifactId>
                <version>${spring-ai.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>com.astraform</groupId>
                <artifactId>astraform-commons</artifactId>
                <version>${project.version}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <dependencies>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <pluginManagement>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-compiler-plugin</artifactId>
                    <configuration>
                        <source>21</source>
                        <target>21</target>
                    </configuration>
                </plugin>
                <plugin>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-maven-plugin</artifactId>
                    <version>${spring-boot.version}</version>
                    <configuration>
                        <excludes>
                            <exclude>
                                <groupId>org.projectlombok</groupId>
                                <artifactId>lombok</artifactId>
                            </exclude>
                        </excludes>
                    </configuration>
                </plugin>
                <plugin>
                    <groupId>org.flywaydb</groupId>
                    <artifactId>flyway-maven-plugin</artifactId>
                </plugin>
            </plugins>
        </pluginManagement>
    </build>

    <repositories>
        <repository>
            <id>spring-milestones</id>
            <name>Spring Milestones</name>
            <url>https://repo.spring.io/milestone</url>
            <snapshots><enabled>false</enabled></snapshots>
        </repository>
    </repositories>
    <pluginRepositories>
        <pluginRepository>
            <id>spring-milestones</id>
            <name>Spring Milestones</name>
            <url>https://repo.spring.io/milestone</url>
            <snapshots><enabled>false</enabled></snapshots>
        </pluginRepository>
    </pluginRepositories>

</project>
EOF

echo "→ Staging all changes..."
git add .

echo "→ Committing..."
git commit -m "chore: restructure services for document processing pipeline

- Remove: form-service, submission-service
- Add: document-service, classifier-service, extraction-service, guidance-service
- Update parent POM modules to match new architecture"

echo "→ Pushing to dev..."
git push origin dev

echo ""
echo "✓ Done. Repo is up to date on dev branch."
echo ""
echo "New service structure:"
echo "  services/api-gateway"
echo "  services/auth-service"
echo "  services/document-service     ← build next"
echo "  services/classifier-service"
echo "  services/extraction-service"
echo "  services/guidance-service"
echo "  services/notification-service"
echo "  services/analytics-service"
echo "  services/billing-service"
