# mi
Rのmiceパッケージを用いた、マルコフ連鎖モンテカルロ法による多重代入法について説明します。ここで示すコードは、それぞれ以下のファイルにも収納してあります。  
+ mi_cross: 横断データに対する多重代入（シングルレベル）
+ mi_long : 縦断データに対する多重代入（マルチレベル）

## インストールと読み込み  
```{r}
#Multiple Imputation for Cross-Sectional Data
install.packages("mice"); install.packages("broom.mixed")
library(mice); library(broom.mixed)
```
## データの読み込みと分布の確認
`mice`パッケージ内に含まれている`nhanes2`のデータを用いて実演します。  
データの型によって、適切な代入の方法が異なるため、まず、`nhanes2`のデータの要約や分布を確認してみます。
```{r}
#1.Check the data distributions and pattern　　
data <- nhanes2; attach(data); summary(data)
par(mfrow = c(2,2)); hist(bmi); hist(chl); plot(age); plot(hyp)
```
`nhanes2`には、25名の年齢（age）、体重（bmi）、高血圧の有無（hyp）、コレステロール値（chl）の4つの変数が含まれていることがわかりました。また、ageは３つのカテゴリー変数、hypは２値のカテゴリー変数、bmiとchlは連続変数です。
```
#>    age          bmi          hyp          chl       
#> 20-39:12   Min.   :20.40   no  :13   Min.   :113.0  
#> 40-59: 7   1st Qu.:22.65   yes : 4   1st Qu.:185.0  
#> 60-99: 6   Median :26.75   NA's: 8   Median :187.0  
#>            Mean   :26.56             Mean   :191.4  
#>            3rd Qu.:28.93             3rd Qu.:212.0  
#>            Max.   :35.30             Max.   :284.0  
#>            NA's   :9                 NA's   :10     
```

次に、それぞれのデータの分布を確認します。例えば、連続変数に対する代入方法の中には正規分布を仮定するものもあるため、非常に歪んだデータなどは注意が必要です。  
![image](https://user-images.githubusercontent.com/82706937/173509244-0078e293-da4c-4023-968f-49ce60316fed.png)  

この次に重要なのは、それぞれの変数に欠損値がどのように発生しているかを確認することです。欠損値の発生状況の確認には、`md.pattern`関数を使用します。  
```{r}
md.pattern(data)
```
![image](https://user-images.githubusercontent.com/82706937/173512297-39e5d84b-e133-49a5-8aa1-782f0cfb15a5.png)  
この表では、データセットにおける欠損値の発生状況を示しており、青は「データあり」、赤は「欠測」です。  
+ **初めの列は、各欠測パターンの頻度を示します。**  
例えば、上の２つをみてみると、全てのデータがある者は13名、chlだけが欠測している者は3名であることがわかります。
+ **最後の列は、各欠測パターンにおける欠測値の数を示します。**  
例えば、一番上の行は全てが青（でーたあり）なので、欠損値の数は０。二番目の行は、4つの変数のうちchlだけ赤（欠損）なので１です。
+ **最後の行は、各変数の欠損値の数を示します**  
例えば、各変数における欠損値は、ageには0個、hypには8個、bmiには9個、chlには10個、それぞれあることがわかります。なお、変数は左から欠損値の少ない順に並べられています。

## 多重代入　Part.1
これは、最もシンプルな多重代入のコードです。`mice`は、各変数の型を自動的に判定し、それぞれ代入を実行します。
```{r}
#2-1.Imputation with default setting (m=5)
imp1 <- mice(data=data, seed = 1234)
```
## 図による代入結果の確認  
代入ができたら、うまく代入できているかプロットして確認します。プロットには、収束プロット、密度プロット、散布図があります。それぞれの図の見方は、次に説明します。
```{r}
#2-2.Plot 
plot(imp1)
densityplot(imp1)
par(mfrow = c(1,2))
stripplot(imp1, chl, pch = 19, xlab = "Imputation number")
stripplot(imp1, bmi, pch = 19, xlab = "Imputation number")
```
### 収束プロット（平均値と標準偏差）
`plot()`で作られるこの図は、横軸をインタラクションの回数として、縦軸に代入した値の平均値や標準偏差などのパラメターをプロットしたものです。それぞれ5本の線があるのは、代入を5回しているためです。この図を見て、**各曲線間におけるばらつきが、個々の曲線内におけるばらつきよりも大きくなっていない場合に、収束していると診断します** (Van Buuren, S. 2018)。 それぞれの変数における曲線の流れを読み取ることで、代入の問題点を見つけることができます。  
![image](https://user-images.githubusercontent.com/82706937/173517190-91495a46-e7c5-490a-ad9a-293d55b10b00.png)  

### 密度プロット（Density Plot） 
![image](https://user-images.githubusercontent.com/82706937/173520401-92dd3a7d-16c2-461e-937d-5c5b3f0c2f6c.png)  
`densityplot()`でつくられるこの図は、観測データと代入済みデータのカーネル密度推定の結果を図にしたものです。青い線は観測データ、赤い線は代入済みデータをそれぞれ示しています。この図において青と赤の線の分布が、大きく異なる場合は注意が必要です。代入モデルが適切ではなかったり、そもそもの欠損データのメカニズムがMCAR（完全に無作為な欠測）でない可能性が考えられます。

### ストリッププロット（Strip Plot） 
![image](https://user-images.githubusercontent.com/82706937/173524212-ad1872fa-fd72-4204-affb-fef3fdee9004.png)  
`stripplot()`で作られるこの図は、横軸を代入の回数として、縦軸を代入された値とした図です。青い点は観測データ、赤い点は代入済みデータをそれぞれ示しています。


<b>参考文献</b> <br>
Van Buuren, S. (2018) Flexible Imputation of Missing Data.
