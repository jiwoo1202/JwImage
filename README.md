
# JwImage

swift 이미지 캐시 라이브러리

## ⚙️ 기능
1. 이미지 다운 샘플링
2. 메모리 캐시
3. 디스크 캐시
4. 네트워크 이미지 다운로드

## 📦 설치 방법

### Swift Package Manager

```
https://github.com/jiwoo1202/JwImage.git
```

## 🖼 사용 방법

### URL

`URL`을 이용해 이미지를 다운로드하고 캐싱합니다.  
표시할 이미지 URL을 전달하면, 내부적으로 **메모리 캐시 → 디스크 캐시 → 네트워크** 순서로 이미지를 탐색합니다.  
기본적으로는 이미지 크기에 맞춰 **자동 다운샘플링**되어 `UIImageView`에 표시됩니다.

```swift
imageView.jw.setImage(with: url)
```

### PlaceHolder
네트워크 요청 중 임시로 표시할 이미지를 설정할 수 있습니다.  
기본값은 `nil`이며, 지정하지 않으면 placeholder가 표시되지 않습니다.

```swift
let placeholder = UIImage(named: "loading")
imageView.jw.setImage(with: url, placeholder: placeholder)
```
### waitPlaceholderTime
`waitPlaceholderTime`은 **placeholder 갱신 주기(대기 시간)** 를 설정합니다.  
placeholder 이미지가 있을 경우, 지정한 시간 간격(초 단위)마다 반복적으로 표시되어  
사용자에게 “로딩 중”임을 시각적으로 알려줍니다.  

- 기본값: `1.0초`
- placeholder가 `nil`일 경우 이 옵션은 무시됩니다.

```swift
// 3초마다 placeholder 다시 표시
imageView.jw.setImage(
    with: url,
    placeholder: UIImage(named: "loading"),
    waitPlaceholderTime: 3.0
)
```
### Options
```swift
// 3초마다 placeholder 다시 표시
imageView.jw.setImage(
    with: url,
    options: [.showOriginalImage, .disableETag]
)
```
| 옵션 | 설명 | 예시 |
|------|------|------|
| `.cacheMemoryOnly` | 이미지를 **메모리 캐시**에만 저장합니다. 디스크 캐시는 사용하지 않습니다. | `.cacheMemoryOnly` |
| `.onlyFromCache` | **캐시에서만** 이미지를 불러옵니다. 네트워크 요청은 하지 않습니다. | `.onlyFromCache` |
| `.forceRefresh` | **항상 네트워크**에서 이미지를 새로 다운로드합니다. | `.forceRefresh` |
| `.showOriginalImage` | 다운샘플링 없이 **원본 해상도 이미지**를 표시합니다. | `.showOriginalImage` |
| `.disableETag` | ETag(HTTP 캐시 검증)를 비활성화하고 항상 서버로부터 전체 응답을 받습니다. | `.disableETag` |
| `.downsamplingScale(Double)` | 다운샘플링 비율을 수동으로 지정합니다. (`1.0` = 기본 크기) | `.downsamplingScale(2.0)` |

# 적용한 기술
<details>
  <summary> 다운 샘플링 적용</summary>

  ### 참고 문헌
  https://devstreaming-cdn.apple.com/videos/wwdc/2018/219mybpx95zm9x/219/219_image_and_graphics_best_practices.pdf
  
  ### 사용한 이유
  - 원본 이미지보다 작은 이미지를 표시할 때, 불필요하게 큰 이미지를 메모리에 올릴 필요가 없음  
  - `Downsampling`을 적용하면 **메모리 사용량이 크게 감소**  
  - 이미지 품질 저하를 최소화하면서 **렌더링 속도와 스크롤 성능을 향상**

  ### 적용 방법
  - WWDC18 - Image and Graphics Best Practices에서 소개된 방법을 사용함

  ### ⚙️ 성능 비교
  
  - **다운샘플링 이미지 vs 원본 이미지** 비교  
  - **테스트 환경:** `XCTest`에서 `XCTMemoryMetric`, `XCTCPUMetric`, `XCTClockMetric` 사용  
  - **테스트 시나리오:** 동일한 이미지를 100회 로드 및 렌더링  
  
  | 다운샘플링 적용 | 원본 이미지 |
  |:--:|:--:|
  | <img width="327" height="261" alt="다운샘플링 이미지" src="https://github.com/user-attachments/assets/95cfd8d5-fcec-4502-bdf0-6dda438f2913" /> | <img width="328" height="265" alt="원본 이미지" src="https://github.com/user-attachments/assets/96f29d05-f274-4960-80fd-0182a922e64d" /> |
  | <img width="270" height="200" alt="다운샘플링 추가 이미지" src="https://github.com/user-attachments/assets/7a0064c7-744b-4be7-838f-4bed1771664d" /> | <img width="269" height="188" alt="원본 추가 이미지" src="https://github.com/user-attachments/assets/b6ce1cf4-ed98-467d-bd51-468b520c8398" /> |
  
  #### 📊 테스트 결과 요약
  
  | 구분 | `Memory Physical` | 메모리 사용량 | CPU 시간 | 실행 시간 |
  |------|---------------|-----------|------------|------------|
  | 원본 이미지 | 약 **350MB** | 약 **440MB** | - | - |
  | 다운샘플링 적용 | 약 **90MB** | 약 **40MB** | - | - |
  
  #### ✅ 성능 비교 결론
  
  - **메모리 효율:** 다운샘플링 적용 시 메모리 사용량이 **약 440MB → 40MB**로 대폭 감소  
  - **CPU와 실행 시간:** 동일한 테스트에서 CPU 사용량과 실행 시간에는 큰 차이가 없었음   
  - **결론:** 다운샘플링을 적용하면 **메모리 사용량 최적화**가 가능하며, iOS 앱에서 이미지 관련 성능을 개선하는 데 효과적임

</details>
<details>
  <summary>diskCache ETag 적용</summary>
<br>
    
ETag를 활용하면 서버 리소스가 변경되지 않았을 때 
불필요한 네트워크 트래픽을 줄일 수 있습니다.  
`diskCache`는 **파일 생성일(`.creationDate`)을 기준으로 만료를 계산**하며,  
서버가 `304 Not Modified`를 응답한 경우 **파일의 생성일을 갱신하여 캐시 수명을 연장**하는 구조를 설계했습니다.

### 동작 흐름

1. 디스크 캐시에서 이미지 데이터 확인  
2. ETag가 존재할 경우 서버에 조건부 요청 (`If-None-Match`) 전송  
3. 서버 응답 분기:
   | 응답 코드 | 처리 방식 |
   |------------|------------|
   | `200 OK` | 새 이미지 다운로드 후 캐시에 저장 |
   | `304 Not Modified` | 동일 데이터로 판단, 캐시 파일 생성일만 갱신 *(설계 의도)* |

---
</details>
<details>
  <summary> Extension Wrapper 적용 이유</summary>
 <br>
Swift의 `Extension Wrapper` 패턴(`.jf`, `.jw` 등 네임스페이스 확장)은  
UIKit 컴포넌트(`UIImageView`, `UIButton`, `UIView` 등)에 기능을 추가할 때  
**전역 네임스페이스 오염을 방지하고**, **라이브러리별 메서드를 명확히 구분**하기 위해 도입되었습니다.

---

### 적용 배경

Swift에서는 
