load(
    "@rules_android//providers:providers.bzl",
    "StarlarkAndroidResourcesInfo",
)

def _collect_assets_impl(ctx):
    all_assets = []

    # ── Walk deps and gather every asset file or directory ──────────────────
    for d in ctx.attr.deps:
        if StarlarkAndroidResourcesInfo in d:
            for asset in d[StarlarkAndroidResourcesInfo].transitive_assets.to_list():
                all_assets.append(asset)

    out_zip = ctx.actions.declare_file("{}_assets.zip".format(ctx.label.name))
    scratch = ctx.actions.declare_directory("{}_assets_dir".format(ctx.label.name))

    if len(all_assets) == 0:
        empty = ctx.actions.declare_file("empty")
        ctx.actions.write(empty, "")
        all_assets.append(empty)

    script = ctx.actions.declare_file(ctx.label.name + "_pack_assets.sh")
    ctx.actions.write(
        script,
        is_executable = True,
        content = """
set -euo pipefail

ITEMS=( {items} )
DEST='{dst}'

for src in "${{ITEMS[@]}}"; do
    if [[ -d "$src" ]]; then
        if [[ -d "$src"/assets ]]; then
            cp -R "$src"/assets/. "$DEST"/
        else
            cp -R "$src"/. "$DEST"/
        fi
    else
        cp "$src" "$DEST"/
    fi
    chmod -R u+w "$DEST"
done

ABS_DEST="$PWD/{zip}"
cd "$DEST" && zip -qqr "$ABS_DEST" .
""".format(
            items = " ".join(['"{}"'.format(item.path) for item in all_assets]),
            dst = scratch.path,
            zip = out_zip.path,
        ),
    )

    ctx.actions.run_shell(
        inputs = depset(all_assets),
        tools = [script],
        outputs = [out_zip, scratch],  # scratch now declared as produced
        command = script.path,
        progress_message = "Collecting Android assets for %{label}",
    )

    return [DefaultInfo(files = depset([out_zip]))]

collect_android_assets = rule(
    implementation = _collect_assets_impl,
    attrs = {
        "deps": attr.label_list(
            allow_rules = ["android_library", "aar_import"],
            allow_files = False,
        ),
    },
    outputs = {"assets_zip": "%{name}_assets.zip"},
    doc = "Zips together every file exposed by AndroidAssetsInfo in deps.",
)
