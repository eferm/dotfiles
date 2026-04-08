const { Plugin, editorInfoField } = require("obsidian");
const { showPanel } = require("@codemirror/view");

function formatDate(ms) {
	const d = new Date(ms);
	return d.toLocaleString(undefined, {
		year: "numeric",
		month: "short",
		day: "numeric",
		hour: "2-digit",
		minute: "2-digit",
	});
}

function updateBar(dom, state) {
	const info = state.field(editorInfoField, false);
	const file = info?.file;
	if (file) {
		dom.textContent =
			"Created: " +
			formatDate(file.stat.ctime) +
			"  \u00b7  Modified: " +
			formatDate(file.stat.mtime);
	} else {
		dom.textContent = "";
	}
}

function createDatePanel(view) {
	const dom = document.createElement("div");
	dom.className = "metabar";
	updateBar(dom, view.state);
	return {
		top: true,
		dom,
		update(update) {
			updateBar(dom, update.state);
		},
	};
}

class MetaBarPlugin extends Plugin {
	onload() {
		this.registerEditorExtension(showPanel.of(createDatePanel));
	}
}

module.exports = MetaBarPlugin;
