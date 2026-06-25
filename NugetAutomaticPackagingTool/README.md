## 配置文件结构：
{
	"target_branch": "目标分支",
	"configuration":"配置",
	"proj_path": ".csproj文件路径(含文件名)",
	"msbuild_path":"MSBuild.exe路径(不含文件名)"
	"nuget_source":"上传仓库路径"
}

## 其他信息
.bat文件需要和config.json在同一个目录下
点击.bat文件即可自动执行打包任务
.bat包含功能：切换目标和更新分支、构建指定版本号的包、给导出包的分支打上标签、将包上传到远程仓库
如需进一步的帮助或信息，请查看文件中的注释或联系项目维护者。