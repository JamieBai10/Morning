import Foundation
for (title, minutes, expected) in [("分镜会",30,"分镜会0.5小时"),("开会",120,"开会2小时"),("学习英语",60,"学习英语1小时"),("跑步",120,"跑步2小时"),("遛狗",30,"遛狗0.5小时"),("剪辑",180,"剪辑3小时"),("写稿子",300,"写稿子5小时"),("看电影",120,"看电影2小时"),("拼豆",210,"拼豆3.5小时")] {
    precondition(YesterdayExpression.calendar(title:title,minutes:minutes) == expected)
}
precondition(YesterdayExpression.calendar(title:"开会",minutes:nil) == "开会")
precondition(YesterdayExpression.task(title:"修改视频") == "你完成了修改视频")
print("Yesterday expression checks passed")
