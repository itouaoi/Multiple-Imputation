![Multiple Imputation with mice](https://user-images.githubusercontent.com/82706937/173745586-c4f51293-a6ff-43be-abee-cd44dd892a2d.png)

`mice`パッケージを用いて欠損値の多重代入法を実行する方法をまとめました。ここでは、はじめに**基本編として「シングルレベルの多重代入法」**、つぎに**応用編として「マルチレベルの多重代入法」** について説明しています。なお、マルチレベルの多重代入法は、何らかの階層（地域、家族など）を持つデータにおける欠損値の多重代入法であり、シングルレベルの多重代入法とは異なるプログラムを組む必要があります。

## コード一覧   
ここで示すコードは、それぞれ以下のファイルにあります。  
+ mi_cross: 基本編「シングルレベルの多重代入法」
+ ~~mi_long : 応用編「マルチレベルの多重代入法」~~(準備中)

## パッケージのインストールと呼び出し  
```r
install.packages("mice")
library(mice)
```

## miceによる多重代入の最も基本的な流れ
`mice`パッケージを使えば、欠損値に対する多重代入法を以下のような数行のコードで実行することができます。  
しかし、データに含まれる変数の種類や分布の形によって適切な多重代入の方法が異なるため、**使用するデータに合わせてカスタマイズする必要があります。**  

```r
# Basic 3 steps workflow
imp <- mice(nhanes)                   #Step1 Imputation
fit <- with(imp, lm(chl ~ bmi + age)) #Step2 Analysis
res <- pool(fit)                      #Step3 Pooling
summary(res)
```

***

# 基本編「シングルレベルの多重代入法」

## 準備：データの要約と分布の確認
`mice`パッケージ内に含まれている`nhanes2`のデータを用いて演習します。  
`nhanes2`のデータを取り込んだら、まずデータの要約や分布を確認してみましょう。
```r
#Check the data distributions and pattern
data <- nhanes2; attach(data); summary(data)
par(mfrow = c(2,2)); hist(bmi); hist(chl); plot(age, main="age"); plot(hyp, main="hyp")
```    

`nhanes2`には、25名の年齢（age）、体重（bmi）、高血圧の有無（hyp）、コレステロール値（chl）の4つの変数が含まれています。それぞれのデータの型は、ageは３つのカテゴリー変数、hypは２値のカテゴリー変数、bmiとchlは連続変数です。
```r
#>    age          bmi          hyp          chl       
#> 20-39:12   Min.   :20.40   no  :13   Min.   :113.0  
#> 40-59: 7   1st Qu.:22.65   yes : 4   1st Qu.:185.0  
#> 60-99: 6   Median :26.75   NA's: 8   Median :187.0  
#>            Mean   :26.56             Mean   :191.4  
#>            3rd Qu.:28.93             3rd Qu.:212.0  
#>            Max.   :35.30             Max.   :284.0  
#>            NA's   :9                 NA's   :10     
```

次に、それぞれのデータの分布を確認します。

![image](https://user-images.githubusercontent.com/82706937/173509244-0078e293-da4c-4023-968f-49ce60316fed.png)  
それぞれ、データの分布は異なりますが、`mice`では、連続変数、カテゴリー変数など様々な種類の変数に対する代入が可能です。

## 準備：欠測パターンの確認
次に重要なのは、**それぞれの変数に欠損値がどのように発生しているか**（欠測パターン）を確認することです。これには、`md.pattern`関数を使用します。  
```r
md.pattern(data)
```
![image](https://user-images.githubusercontent.com/82706937/173512297-39e5d84b-e133-49a5-8aa1-782f0cfb15a5.png)  
この図では、データセットにおける欠損値の発生状況を示しており、青は「データあり」、赤は「欠測」です。  
+ **初めの列は、各欠測パターンの頻度を示します。**  
例えば、上の２つをみてみると、全てのデータがある者は13名、chlだけが欠測している者は3名であることがわかります。
+ **最後の列は、各欠測パターンにおける欠測値の数を示します。**  
例えば、一番上の行は全てが青（データあり）なので、欠損値の数は０。二番目の行は、4つの変数のうちchlだけ赤（欠損）なので１です。
+ **最後の行は、各変数の欠損値の数を示します**  
例えば、各変数における欠損値は、ageには0個、hypには8個、bmiには9個、chlには10個、それぞれあることがわかります。なお、変数は左から欠損値の少ない順に並べられています。

**色々な欠測パターン**  
![image](https://user-images.githubusercontent.com/82706937/174927905-c5f4cf0e-a49b-48fd-a1c3-64f3bd988943.png)  
図：欠測値の種類の例。青は観測値、赤は欠測値を示す。（Van Buuren, S, 2018, p.106, Figure 4.1を一部改変して作成）    
+ **単変量欠測パターン（Univariate）**　一つの変数のみ欠測が発生しているパターンです。   
+ **単調欠測パターン（Monotone）**　欠測値の少ない変数を左から順に並べたときに、左から右へ欠測率が高くなっているパターンです。参加者の脱落など、縦断的な調査でよくみられます。     
+ **File matchingパターン**　ある変数の有無によって、観測値が結合した／結合していない形へと変化する欠測パターンです。例えば、一番左の列が無ければ、その横の二つの列は観測値で結合できる部分が無くなってしまいます。  
![image](https://user-images.githubusercontent.com/82706937/174931511-ba5cf2fd-c5fc-44be-8b94-c643a1c0a317.png)  
+ **一般的な欠測パターン**　最もよくある欠測パターンです。上のFile matchingと異なる点は、一番左の列が無くてもその横の二つの列が観測値によって結合しているという点です。  
  
![POINT (4)](https://user-images.githubusercontent.com/82706937/173995184-0feeb0ea-d782-4055-b300-c162c7a032b1.png)  
**欠測値を代入する前に、「データの要約と分布」と「欠損値の発生パターン」を確認する**  
***

## 代入ステップ
`mice`パッケージを用いた多重代入は、`mice()`による**代入**、`with()`による**分析**、`pool()`による分析結果の**統合**の３ステップに分けられます。まず、最初のステップである代入から説明します。

`mice()`を使った代入は、以下のコードで実行できます。
```r
#1-1.Imputation with default setting (m=5)
imp1 <- mice(data=data, seed = 1234)
```  
`mice()`のdataには、代入を行いたいデータセットを指定し、seed（シード値）は、再現性のある結果を得るために必要です。なお、ここではまだ必要最低限の引数しか指定していませんが、`mice()`はデフォルトの設定を自動的に適用し、代入を実行します。  

## 図による代入結果の確認  
上記のコードを使って代入ができたら、**代入の結果をプロットして確認しましょう**。代表的なプロットとしては、**収束プロット、密度プロット、散布図**があります。それぞれの図の見方を簡単に説明します。
```r
#1-2.Plot 
plot(imp1)
densityplot(imp1)
stripplot(imp1, pch = 19, xlab = "Imputation number")
```
### １．収束プロット（平均値と標準偏差）  
![image](https://user-images.githubusercontent.com/82706937/173517190-91495a46-e7c5-490a-ad9a-293d55b10b00.png)  
`plot()`で作られるこの図は、横軸を反復の回数として、縦軸に代入した値の平均値や標準偏差などのパラメターをプロットしたものです。それぞれ5本の線があるのは、代入を5回しているためです。この図を見て、**「各曲線間におけるばらつき」が「個々の曲線内におけるばらつき」よりも大きくなっていない場合に、収束していると診断します** (Van Buuren, S. 2018)。 それぞれの変数における曲線の流れを読み取ることで、代入の改善点を見つけることができます。  

### ２．密度プロット（Density Plot） 
![image](https://user-images.githubusercontent.com/82706937/173520401-92dd3a7d-16c2-461e-937d-5c5b3f0c2f6c.png)  
`densityplot()`でつくられるこの図は、観測データと代入済みデータの密度をそれぞれ示したものです。青い線は観測データ、赤い線は代入済みデータをそれぞれ示しています。この図において青と赤の線の分布が大きく異なる場合は注意が必要です。その場合は、代入モデルが適切ではなかったり、そもそもの欠損データのメカニズムがMCAR（完全に無作為な欠測）でない可能性が考えられます。  

例えば、上記の図例からは、観測データと代入済みデータの密度が、chlよりもbmiで大きくずれていることがわかります。  

### ３．ストリッププロット（Strip Plot） 
![image](https://user-images.githubusercontent.com/82706937/173524212-ad1872fa-fd72-4204-affb-fef3fdee9004.png)  
`stripplot()`で作られるこの図は、**横軸を代入の回数(m)、縦軸を各変数の観測値と代入された値**とした図です。青い点は観測データ、赤い点は代入済みデータをそれぞれ示しています。

***

## 分析ステップ
欠損値の代入ができたら、次は`with()`を使って分析を行います。分析ステップでは、ｍ組の疑似的な完全データを標準的な統計手法を用いてｍ回解析し、パラメータ推定値とその分散を得ます（阿部, 2016, p96）。用いることのできる統計手法は様々ですが、ここでは回帰分析を用いて分析していきます。  
```r
#2. Analysis
fit1 <- with(imp1, lm(chl ~ bmi + age)) 
```

## 統合ステップ
分析ステップの次は、`pool()`を使ってすべての結果を**統合**します。   
`summary()`を使って、最終的な解析結果の要約を確認することができます。

```r
#3. Pooling the results
res1 <- pool(fit1)
```

```r
res1
#> Class: mipo    m = 5 
#>          term m  estimate        ubar           b           t dfcom        df       riv    lambda       fmi
#> 1 (Intercept) 5 10.663179 3019.802215 727.1210629 3892.347491    21 12.575300 0.2889412 0.2241694 0.3237926
#> 2         bmi 5  5.617963    3.658844   0.7508079    4.559813    21 13.422759 0.2462443 0.1975891 0.2953085
#> 3    age40-59 5 48.705149  249.114148  98.2435756  367.006438    21  9.772408 0.4732461 0.3212268 0.4275142
#> 4    age60-99 5 65.834508  288.402561 351.8903635  710.670997    21  4.623812 1.4641633 0.5941827 0.7006432

summary(res1)
#>          term  estimate std.error statistic        df    p.value
#> 1 (Intercept) 10.663179 62.388681 0.1709153 12.575300 0.86700972
#> 2         bmi  5.617963  2.135372 2.6309059 13.422759 0.02030861
#> 3    age40-59 48.705149 19.157412 2.5423658  9.772408 0.02973143
#> 4    age60-99 65.834508 26.658413 2.4695584  4.623812 0.06056866
```
上記の結果を一度に表示したい場合は、以下のコードを用います。
```r
summary(res1, "all", conf.int = TRUE)
```
***
# 発展：基礎編「シングルレベルの多重代入法」をカスタマイズ
ここからは`mice()`の様々な引数をカスタマイズして、様々なデータの大きさ、型（連続変数、カテゴリ変数）、分布の形（正規分布、非正規分布など）などに対応する、よりフレキシブルな代入を行うための方法を説明します。

### mice()の使い方の詳細
`mice()`は代入を実行する関数ですが、引数に渡す値を操作することでフレキシブルな代入を行うことができます。様々な引数がありますが、特に重要な引数として**data（代入したいデータセットの指定）、predictorMatrixまたはpred（代入に用いる予測変数の指定）、method（代入に用いる方法の指定）、m（代入回数の指定）、maxit（反復の回数の指定）** があります。

```r
#Usage of mice (ver 3.14.0)
mice(
  data,
  m = 5,
  method = NULL,
  predictorMatrix,
  ignore = NULL,
  where = NULL,
  blocks,
  visitSequence = NULL,
  formulas,
  blots = NULL,
  post = NULL,
  defaultMethod = c("pmm", "logreg", "polyreg", "polr"),
  maxit = 5,
  printFlag = TRUE,
  seed = NA,
  data.init = NULL,
  ...
)
```

***
## とくに重要な引数（method, pred, maxit, m）  
#### method: 各変数の代入方法の指定
`mice()`の引数であるmethodは、各変数に対する代入方法を指定します。指定できる代表的な方法には、**pmm、norm、logreg、polyreg**などがあります。 もし、この引数をとくに操作しなければ、`mice()`は自動的に変数のデータ型を区別して適切な方法を指定します。しかし、その自動的に指定された方法が必ずしも最適な方法かは分からないため注意が必要です。  例えば、代入したい変数のデータの型が連続変数の場合はデフォルトでpmmが指定されますが、その連続変数が正規分布している場合はnormの方が効率的かもしれません（Van Buuren, S, 2018, p.166）。

下の表に示した方法は、特によく用いられる方法です。

表. method引数で指定できる方法  
|  Method  | 説明 | 変数の型  |
| ---- | ---- | ---- |
|  pmm  | 予測的平均マッチング  | 何でも（数値型、カテゴリーなど）  |
|  midastouch  |  重み付き予測的平均マッチング  |   何でも（数値型、カテゴリーなど）  |  
|  norm  |  ベイズ線形回帰  |  数値  |
|  logreg  |  ロジスティクス回帰  |  二値  |
|  polyreg  |  多項ロジスティック回帰  |  名義  |
|  polr  |  比例オッズモデル  |  順序  |

## method の違いによる代入結果の違い
### 例: normとpmmの比較  
実際に、norm（ベイズ線形回帰）とpmm（予測的平均マッチング）による代入の結果を比較してみます。  
**コード**  
`mice()`の中の`method=c("", "pmm", "logreg", "pmm")`で各変数の代入の方法を指定しています。指定する順は、データの変数の並び（age, bmi, hyp, chl）と同様です。代入が不要な変数には、""と指定します。hypは、二値変数なので"logreg"を指定します。  

連続変数のbmiやchlは、pmmでもnormでもどちらでも代入可能です。方法が異なることによって、代入の結果がどのように異なるのかを確認してみましょう。  

```r
#4-1.Imputation with predictive mean matching
require(mice); data <- nhanes2; attach(data)
head(data)
imp2 <- mice(data = data, seed = 1234, m=5, maxit=5,
             method=c("", "pmm", "logreg", "pmm"))

stripplot(imp2, pch = 19, xlab = "Imputation number
          Predictive mean matching (pmm)")


#4-2.Imputation with Bayesian linear regression 
imp3 <- mice(data = data, seed = 1234, m=5, maxit=5,
             method=c("", "norm", "logreg", "norm"))

stripplot(imp3, pch = 19, xlab = "Imputation number
         Bayesian linear regression (norm)")
```
**結果**  
pmm（予測的平均マッチング）による代入  
![image](https://user-images.githubusercontent.com/82706937/173991396-362185ed-fef5-48a4-95fd-495090e73317.png)  

pmmは、いろいろな型の変数に適用できる便利な方法です。どの代入値（赤点）も、観測値（青点）の分布している範囲内に収まっています。pmmは、回帰モデルによって求められた値と最も近い観測値を代入値とするため、変数内の観測値と異なる値が代入されることはありません。

norm（ベイズ線形回帰）による代入  
![Rplot](https://user-images.githubusercontent.com/82706937/173996575-3523d42e-0bf5-4767-952b-6edb0d4f1184.png)

normは、特に変数のデータが正規分布している場合にスピーディに代入を行える便利な方法です。しかし、変数のデータが正規分布と程遠い場合は、上手く代入が行えない場合があるため注意が必要です。  図を見てみると、pmmで代入した場合と比較して、いくつかの代入値（赤点）は観測値（青点）の分布から外れていることがわかります。特に、左図のbmiでは、一番下の代入値（赤点）を見てみると、BMIが15以下のような**現実では観測されにくい値**の代入も行われています。 

***

#### pred: 各変数の代入に用いる変数の指定
`mice()`の引数であるpredは、欠損値の代入に使用する予測変数を指定する引数で、0と1からなる行列が指定されます。0は「予測変数として使用しない」、1は「予測変数として使用する」ことを示します。デフォルトでは、予測変数に**その変数自体を除く全ての変数**が指定されます。

```r
imp <- mice(data = data, seed = 1234, print = FALSE)
imp$pred
#>     age bmi hyp chl
#> age   0   1   1   1
#> bmi   1   0   1   1
#> hyp   1   1   0   1
#> chl   1   1   1   0
```
オブジェクト名＋`$pred`で、代入に用いられた予測変数を確認できます。例えば、以下の表の場合は、ageの代入に用いる予測変数としてsex, hyp, chlを用いることを意味しています。  

**どれくらい多くの変数を含める？**  
通常は、より多くの変数を予測変数として含めることによって、**最小のバイアスかつ最大の効率性をもった多重代入**が可能と報告されています（Meng, 1994; Collins et al., 2021）。また、多くの変数を予測変数を含めることによって、**MAR（ランダムな欠測）の仮定をより確かなものとする**上でも有用といわれています（Van Buuren, S, 2018, p.167）。  

しかしながら、このより多くの変数を含めるというテクニックは、20～30個の変数の場合では当てはまるかもしれないが、例えば100個といった**非常に多くの変数を含む場合は当てはまらない可能性もあります**。この場合は、収束の結果を見ながら予測変数として用いる変数の数を調整すると良いと思います。  

**大きいデータセットの場合のpredの操作**
例で用いているような小さなデータセットの場合は行列の値を簡単に変えられますが、大きなデータセットでは変数の種類が多く非常に面倒です。大きなデータセットの場合、predの行列をcsvファイルとして保存してエクセルで編集すると簡単です。  

デフォルトのpredを、csvファイルに変換する。  
```r
#5-2. Make a original predictor matrix for big data set.
pred <- imp$pred
write.csv(pred, file = "test.csv")
```
csvファイルを開き、各セルの値を編集します。  
![image](https://user-images.githubusercontent.com/82706937/174018538-4d788e10-637a-482d-b3bf-d2804dd9b1d9.png)    
エクセルで「ホーム」→「条件付き書式」→「カラースケール」から、セルの色を変えると視覚的にもわかりやすくて便利です。  
![image](https://user-images.githubusercontent.com/82706937/174018734-8a158986-b6c9-487a-b8b3-4d532f86630b.png)    

例えば、以下のようにageの列をすべて0にした場合、全ての変数（hyp, bmi, chl）の代入でageを使用しないことを意味します。このように、予測変数として使用したい変数を自由に操作することができます。  
![image](https://user-images.githubusercontent.com/82706937/174018494-be27b21b-6e4a-4034-8d35-88ba17b4c571.png)  
変数を操作したら上書き保存して、Ｒに取り込みます。  

```r
pred_2 = read.csv("test.csv", header = T, row.names = 1)
pred_2 <- as.matrix(pred_2); pred_2
```
以下の`pred = pred_2`のように、変更したpredの行列を指定すればその指定に沿った代入が行われます。  
```r
imp4 <- mice(data = data, seed = 1234, print = FALSE,
             pred = pred_2)
```  
![POINT (4)](https://user-images.githubusercontent.com/82706937/173995184-0feeb0ea-d782-4055-b300-c162c7a032b1.png)  
**データセット内の変数が多い時（20個以上など）は、予測変数を指定するpredの行列をエクセルで編集すると便利**  
***
#### maxit: 反復回数（interactions）  
`maxit`は、各代入におけるマルコフ連鎖の反復回数を指定する引数です。この反復が繰り返されることによって代入値が収束していくため、重要な値です。デフォルトでは、5回（`maxit = 5`）で設定されています。5回でも代入値が収束しない場合は10回、20回と増やしてみると良いと思います。  

**反復回数を変えるとどうなるか**  
反復回数を5回と20回の場合で、収束プロットを比較してみると以下のようになります。左の図が反復回数が5回、右の図が反復回数が20回です。代入の回数は、どちらも20回で同じです。    
![image](https://user-images.githubusercontent.com/82706937/174043143-930db4b2-9c2b-4c71-a02e-2889a9a4245d.png)    
反復回数が5回と少ない左の図は、各代入の線同士のばらつきが大きく収束していないように見えます。それに対して、反復回数20回の右の図を見ると、収束しているとは言い切れませんが、左と比較して各代入の線がよく交わっており、各線間におけるばらつきが個々の線内におけるばらつきよりも大きくないことがわかります。  

***
#### m: 代入の回数  
`m`は、代入の回数を指定する引数です。デフォルトは5回（`m = 5`）で設定されています。  

**どれくらいの代入が必要？**  
**20～100回**の代入が勧められています（Van Buuren, S, 2018, p.58）。過去には、3～5回といった少ない回数でも十分であると考えられていましたが、多重代入の研究が進み、現在ではより多くの回数の代入が勧められるようになりました。また、代入の回数をデータにおける欠測率と似た値にするべきとする研究者もいます（Von Hippel, 2009）。  

***
# 応用編「マルチレベルの多重代入法」
準備中  
***
# 補足
**エラー対処法について**  
+ `mice()`の代入が途中で止まる。  
broom.mixedパッケージを呼び出す、またはRのパッケージをアップデートする。  


**用語の確認**  
+ R：統計解析を行うためのプログラミング言語のフリーソフト。ここではR version 4.2.0を使用。  
+ 関数（function）：ある一連の処理のまとまり。命令に従って処理を実行し、結果を返す。この結果を返り値や戻り値という。  
+ 引数（argument）：関数に渡す値のこと。 
+ 欠測パターン（missing pattern）：データセット内における観測値と欠測値の発生パターンのこと。  
+ 反復（interaction）：マルコフ連鎖がとる反復の回数 


<b>参考文献</b> <br>
+ Van Buuren, S. Flexible Imputation of Missing Data (2018)  
+ 高橋 将宜, 渡辺美智子著 (2017) 欠測データ処理 : Rによる単一代入法と多重代入法 (共立出版, 2017) 
