### 引言
在异步编程中,当异步任务完成时一般用两种方式来通知主调方异步任务的完成(也叫回调):代理和闭包. 在使用闭包时,如果要开启多个异步任务,难免就会出现"回调地狱"的问题,而使用Promise就可以把闭包里嵌套的写法改成链式调用的的写法,回调地狱也就被展平了,很是神奇.当点开Promise源码探究其原理时,就像看天书一样,很难理解,比如一个Promise对象中会有一个叫work的属性(有的也叫task)如下:
```swift
let work: ((Value) -> Void,(Error) -> Void) -> Void
```
通过typealias给相关类型起别名后:
```swift
 typealias ResolveCallback = (Value) -> Void
 typealias RejectCallback = (Error) -> Void
 typealias Work = (ResolveCallback, RejectCallback) -> Void
 let work: Work
```
再看work的类型会稍微清晰了一点,work是一个有两个参数并返回值为空的函数,其中这两个参数又分别是参数为Value或Error并且返回值为空的函数.可能看到这里你也会有这些疑问:
* 为什么要定义这么奇怪的类型?
* 为什么这个类型就能解决回调嵌套的问题?

带着这些疑问硬着头皮继续看源码还是一头雾水,直到了解了一些关于函数式编程的东西,我才稍微有点眉目.接下来我会一步一步从最简单的概念和例子来理解函数式编程,并最终理解Promise的逻辑.Let's go!

### 函数式编程
关于函数式编程的介绍目前已经有很多书籍和文章,其最核心的思想是把函数作为 **"一等值"** 来参与运算.
> *所谓 **一等值** 是指函数这种类型和一般的整形,布尔型,集合型的地位一样,可以作为函数的参数参与运算,也可以作为一个函数的返回值,同样也可以把一个函数赋值给一个常量或变量.*

当你写的代码有以上三种行为的任意一种时,恭喜你,你已经使用了**函数式编程**,虽然你自己可能还没意识到,其实你每天写的用URLSession发起网络请求的代码已经用到了**函数式编程**,举个例子,如下业务是先获取自己的所有粉丝,然后关注第一个:
```swift
URLSession.shared.dataTask(with: allFansUrl, completionHandler: {data, response, error in
    if let data = data{
        // 请求成功,解析data,获取第一个粉丝的UserID,然后发起关注请求
        URLSession.shared.dataTask(with: careUserUrl, completionHandler: {data, response, error in
            if let data = data{
                // 请求成功,解析data,关注成功
            }else{
                // 请求失败,处理错误
            }
        }).resume()
    }else{
        // 请求失败,处理错误
    }
 }).resume()
```
这样的代码可能我们每天都会写,但是如果不仔细想想completionHandler这个参数到底是什么类型的话,就体会不出来,如果换下面的写法,就会清楚一点了:

```swift
let allFansHandler:(Data?, URLResponse?, Error?) -> Void  = { data, response, error in
    if let data = data{
        // 请求成功,解析data,获取第一个粉丝的UserID,然后发起关注请求
        let careUserHandler:(Data?, URLResponse?, Error?) -> Void  = { data, response, error in
            if let data = data{
                // 请求成功,解析data,关注成功
            }else{
                // 请求失败,处理错误
            }
        }
        URLSession.shared.dataTask(with: careUserUrl, completionHandler: careUserHandler).resume()
    }else{
        // 请求失败,处理错误
    }
}
URLSession.shared.dataTask(with: allFansUrl, completionHandler: allFansHandler).resume()
```
我们先定义了一个allFansHandler,并把它和另一个allFansUrl作为参数传入到了URLSession的dataTask(::)函数中来发起获取所有粉丝的请求,至此其实这段代码就已经结束了,只是因为网络请求是一个异步行为,还在后台线程执行中,一段时间后,网络请求结束,会使用获取到的数据作为参数,调用completionHandler这个函数,completionHandler的值,也正是我们在之前定义的allFansHandler这个函数并作为参数传入进来的,如下是NSURLSession中dataTask(::)方法的实现:
```swift
class NSURLSession{
    func dataTask(url: URL, completionHandler:(Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask{
        // 在后台线程发起网络请求
        // ...
        // 一段时间后,网络请求成功或者失败,执行回调
        completionHandler(data,response,error)
    }
}
```
既然allFansHandler这个函数作为参数传入到了一个函数中,那这种行为就是**函数式编程**,同理, careUserHandler这个函数也是这种情况.这样看来,**函数式编程**是不是很简单? 然而,我们目前只是使用了**函数式编程**的其中一部分特点:
> *把一个函数作为参数传入一个函数*

并且你也发现了,目前的两个网络请求是嵌套的关系,是我们需要用Promise去解决的.再回头看上面关于**一等值**的描述,还有另外两部分我们似乎还没用到:
> *可以作为一个函数的返回值,同样也可以把一个函数赋值给一个常量或变量*

接下来的例子会一步一步用到,并最终看Promise是如何使用的.

### 函数的合成

所谓函数的合成是指把两个函数合成一个新的函数,新的函数所能达到的行为和两个函数所能达到的行为一致.可以类比我们人类,此时可以把函数称作"技能"或者"本领",这样会比较好理解.比如一个人学会了如何砍树,此时他的脑袋里就有了一项 **"把一颗树变成木材"** 的本领,不久后,他又学会了 **"用木材做板凳"** 的本领.此时如果我说他的脑袋里有了三项本领,你会不会觉奇怪呢?
* 1: 把树变成木材
* 2: 把木材变成板凳
* 3: 把树变成板凳

没错,第三项本领就是把前两项合成后得出的一项新本领,也许你会说第三项本领根本不能单独算一种,那可以考虑这样一种情景: 一个招聘启示上写着:"我们公司需要一个能 **把树变成板凳** 的人",而你想了一下,我只有 1 ,2 两项本领,并且这两项本领的任何一项都不符合这个要求,那你恐怕就错过了这次招聘了.函数的合成也类似第三项本领的合成,用代码表示如下:
```swift
struct Tree{}
struct Wood{}
struct Bench{}

class People{
    let makeWoodSkill: (Tree) -> Wood = { tree in
        print("start lumbering \(tree)...")
        print("lumbering done, get a wood")
        let wood = Wood()
        return wood
    }
    
    let makeBenchSkill: (Wood) -> Bench = { wood in
        print("start making Bench by \(wood)...")
        print("making Bench done, get a Bench")
        let bench = Bench()
        return bench
    }
    
    func compose<A,B,C>(_ skillOne:@escaping (A)->B, _ sikllTwo:@escaping (B)->C) -> (A)->C{
        let newSkill: (A)-> C = { a in
            let b = skillOne(a)
            let c = sikllTwo(b)
            return c
        }
        return newSkill
    }
}

```
此时,这个人脑袋里只定义了两项本领makeWoodSkill和makeBenchSkill,我们并没有定义刚才说的第三项,而是定义了一个compose函数,这个函数的作用就是把两项本领合成一项新本领,并且使用了泛型参数,其中skillOne是一项可以把A变成B的本领,skillTwo是一项可以把B变成C的本领,于是,新的本领newSkill就是一项可以把A变成C的本领,其实这项本领所做的事情就是先使用skillOne本领把a变成b,然后使用skillTwo把b变成c.要得到第三项本领skillTreeToBench,只需要调用这个函数即可:
```swift
let p = People()
let skillTreeToBench = p.compose(p.makeWoodSkill, p.makeBenchSkill)

let tree = Tree()
let Bench = skillTreeToBench(tree)

// 输出:
// start lumbering Tree()...
// lumbering done, get a wood
// start making Bench by Wood()...
// making Bench done, get a Bench

```
假如这个人又学会了把板凳做成沙发的本领:
```swift
class People{
    let makeSofaSkill: (Bench) -> Sofa = { bench in
        print("start making sofa by \(bench)...")
        print("making sofa done, get a sofa")
        let sofa = Sofa()
        return sofa
    }
}
```

此时他总共有几项本领呢?(答案是6项)
* 1: 把树变成木材
* 2: 把木材变成板凳
* 3: 把板凳变沙发
* 4: 把树变成板凳
* 5: 把木材变沙发
* 6: 把树变沙发

前三项是在这个人的脑袋里面刻着的(对应就是在People类定义的),而后三项是可以随时通过compose函数合成的,所以就没必要定义出来,如果你非要定义出来也没问题,只是没这个必要,为什么呢? 设想一下,假如这个人学了100项技能,然后就可以另外合成上千种技能,难道这些组合出的技能你也要在People类中写出来吗?,所以完全没必要.
再看compose函数,它既使用了函数作为参数,又把函数作为返回值,同时又把返回值赋值给skillTreeToBench这个临时变量,那它很**函数式编程**啊,可能你会问:
* 用普通的 **命令式编程** 也可以解决啊,这么做的意义是什么呢?
* **函数式编程** 究竟能解决什么问题呢?

### 命令式编程
可以说我们之前大部分写的程序都是命令式的,命令式编程的主要思想是关注计算机执行的步骤，即一步一步告诉计算机先做什么再做什么,必须得等前一步执行完并拿到结果,才能带着第一步的结果启动第二步的执行,还拿上个例子来说,此时要用一棵树造一个沙发,命令式编程会写如下代码:
```swift
class People{
    func makeWood(tree: Tree) -> Wood{
        print("start lumbering \(tree)...")
        print("lumbering done, get a wood")
        let wood = Wood()
        return wood
    }
    
    func makeBench(wood:Wood) -> Bench{
        print("start making Bench by \(wood)...")
        print("making Bench done, get a Bench")
        let bench = Bench()
        return bench
    }
    
    func makeSofa(bench:Bench) -> Sofa{
        print("start making sofa by \(bench)...")
        print("making sofa done, get a sofa")
        let sofa = Sofa()
        return sofa
    }
}

let p = People()
let tree = Tree()
let wood = p.makeWood(tree: tree)
let bench = p.makeBench(wood: wood)
let sofa = p.makeSofa(bench: bench)
```
从上面的代码可以看出,后一个步骤的执行要依赖前一步的结果,所以才产生了三次依赖:
* 1:做沙发依赖板凳
* 2:做板凳依赖木材
* 3:做木材依赖砍树

写成如下方式就是嵌套的结构:
```swift
let sofa = p.makeSofa(bench: p.makeBench(wood: p.makeWood(tree: tree)))
```
如果你觉得这还不是很"嵌套",那是因为目前行为都是同步的,假如写成异步的行为如下:
```swift
extension People{
    func makeWoodAsync(tree: Tree, completeHandler:@escaping (Wood)->Void ) {
        print("start making wood by \(tree)...")
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            print("lumbering done, get a wood")
            let wood = Wood()
            completeHandler(wood)
        }
    }
    
    func makeDeskAsync(wood:Wood, completeHandler:@escaping (Desk)->Void ) {
        print("start making desk by \(wood)...")
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            print("making desk done, get a desk")
            let desk = Desk()
            completeHandler(desk)
        }
        
    }
    
    func makeSofaAsync(desk:Desk, completeHandler:@escaping (Sofa)->Void ) {
        print("start making sofa by \(desk)...")
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            print("making sofa done, get a sofa")
            let sofa = Sofa()
            completeHandler(sofa)
        }
    }
}
let p = People()
let tree = Tree()

p.makeWoodAsync(tree: tree) { wood in
    p.makeDeskAsync(wood: wood) { desk in
        p.makeSofaAsync(desk: desk) { sofa in
            print("get a \(sofa)")
        }
    }
}

```
现在是不是相当"嵌套"了,这正是**命令式编程**的一个最大的问题,再回头看本文开头的那个网络请求的例子,之所以产生回调地狱问题也是因为这个原因,后一个请求必须要使用前一个请求的返回结果才能启动,所以也是嵌套的结构.

下面我们用**函数式编程**来实现一下这个功能,看是否也会出现依赖嵌套的问题.
首先要把脑袋里的三项技能合成一个名字叫:"把树变沙发"的本领skillTreeToSofa(上面第6项本领),然后再使用这项技能把一棵树做成沙发:
```swift
class People{
    let makeWoodSkillAsync: (Tree, @escaping (Wood)->Void) -> Void = { tree, completeHandler in
        print("start making wood by \(tree)...")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            print("lumbering done, get a wood")
            let wood = Wood()
            completeHandler(wood)
        }
    }
    
    let makeDeskSkillAsync: (Wood, @escaping (Bench)->Void ) -> Void = { wood, completeHandler in
        print("start making bench by \(wood)...")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            print("making bench done, get a bench")
            let bench = Bench()
            completeHandler(bench)
        }
    }
    
    let makeSofaSkillAsync: (Bench, @escaping (Sofa)->Void ) -> Void = { bench, completeHandler in
        print("start making sofa by \(bench)...")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            print("making sofa done, get a sofa")
            let sofa = Sofa()
            completeHandler(sofa)
        }
    }
}

extension People{
    func compose<A,B,C>(_ skillOne:@escaping (A,@escaping (B)->Void) -> Void,
                      _ skillTwo:@escaping (B,@escaping (C)->Void) -> Void
                      ) -> (A,@escaping (C)->Void) -> Void {
        
        let newSkill: (A,@escaping (C)->Void) -> Void = { a, completeHandler in
            skillOne(a){ b in
                skillTwo(b){ c in
                    completeHandler(c)
                }
            }
        }
        return newSkill
    }
}
```
注意,目前三项技能都是异步技能,所以在名字后面都加上了"Async".而compose函数目前虽然看着很复杂,但是不要被它吓住了,它的功能依然是合并两项技能,只是此时合并的是两项异步技能,如果看着费劲的话,不如我们给异步技能起个别名如下:
```swift
typealias AsyncSkill<I,O> = (I, @escaping (O)->Void) -> Void
```
我们定义了一个泛型的异步技能AsyncSkill<I,O>,它表示一项可以 **把I(input)变成O(output)的异步技能** ,改写compose函数:
```swift
func compose<A,B,C>(_ skillOne:@escaping AsyncSkill<A,B>,
                  _ skillTwo:@escaping AsyncSkill<B,C>
                  ) -> AsyncSkill<A,C> {
    return { a, completeHandler in
        skillOne(a){ b in
           skillTwo(b){ c in
                completeHandler(c)
            }
        }
    }
}
```
现在是不是清晰了一点?compose依然是在合并两项技能,生成的新技能其实就是先调用skillOne再调用skillTwo,调用skillOne的方式和之前我们调用makeWoodAsync函数是一样的.接下来就是使用这个compose函数把三项技能合成一项技能,并使用这项技能了:
```swift
let p = People()
let tree = Tree()

let skillTreeToBenchAsync = compose(p.makeWoodSkillAsync, p.makeDeskSkillAsync)
let skillTreeToSofaAsync = compose(skillTreeToBenchAsync, p.makeSofaSkillAsync)
skillTreeToSofaAsync(tree){ sofa in
    print("get a \(sofa)")
}
```

似乎和**命令式编程**出现了同样的问题:skillTreeToSofaAsync的生成依赖于前一步的结果skillTreeToBenchAsync,这种依赖和同步行为下的命令式编程中出现的依赖一样,但是现在的代码明显改善了两点:
* 1: 虽然有依赖但是只有一次,而之前是三次
* 2: 虽然是技能是异步的,但技能的合成却是同步的,既compose函数是同步的

在解释使用**函数式编程**后为什么会有如此功效前,我还想展示另外一种合成技能方式:
```swift
let skillWoodToSofaAsync = compose(p.makeBenchSkillAsync, p.makeSofaSkillAsync)
let skillTreeToSofaAsync = compose(p.makeWoodSkillAsync, skillWoodToSofaAsync)
```
仔细和上面的方式对比一下,这次是先把后两项本领合成skillWoodToSofaAsync,然后再和第一项本领合成最终的本领,如果你被绕晕了也可以看下面这张图:
![本领转换](https://gitee.com/hwreal/mdimages/raw/master/2021/QQ20211110-025603@2x.png)
* 三个黑色箭头代表People的三项技能
* 绿色箭头代表先把前两项技能合并,合并后的技能再和第三项技能合并
* 红色箭头代表先把后两项技能合并,合并后的技能再和第一项技能合并

把三项技能合并成一项时既可以先合并前两项,又可以先合并后两项.假设目前有10项技能,要把这些技能合成一项,最简单的方式就是从前往后一项一项合并.也可以先两两合并,然后再把结果两两合并...
总之,组合方式就有很多种,虽然最终生成的技能依赖于前面所产生的技能,但是前面技能的产生顺序是可以一定程度上是任意的(注意:是一定程度上),而**命令式编程**是严格的依赖关系:前一个技能执行并产生结果,后一项技能才能开始. 


其实我们仔细观察compose函数就能得出答案,compose是把两项技能合并成一项新的技能:
```swift
(SkillOne, SkillTwo) -> NewSkill
```
其中skillOne此时只是一项技能,它只存在这个人的脑袋里面,如果这个人很懒惰,一直不去使用这项技能,那它仅仅存在脑袋里,不会产生结果.而skillOne可以是从这个人所有技能的任何一个开始的,比如上图中,我们可以直接从第二项技能开始,先把第二项和第三项技能合并:
```swift
let skillWoodToSofa = p.compose(p.makeBenchSkill, p.makeSofaSkill)
```
也就是:用 **"木材变板凳"** 的技能 和 **"板凳变沙发"** 的技能 合并成 **"木材变沙发** 的技能, skillOne就是**木材变板凳**,此时skillOne只是一项技能,这项技能里的木材虽然是从树木来的,但是现在不需要先拿到一个真正的木材,也就不需要先执行砍树的本领.而**命令式编程**必须得先有木材才行,也就是必须得先砍一颗树变成木材,然后才能执行下面的操作.












