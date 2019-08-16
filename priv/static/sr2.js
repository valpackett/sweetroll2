(function () {
	function throttle (timer) {
		let queuedCallback
		return callback => {
			if (!queuedCallback) {
				timer(() => {
					const cb = queuedCallback
					queuedCallback = null
					cb()
				})
			}
			queuedCallback = callback
		}
	}


	customElements.define('responsive-container', class extends HTMLElement {
		alignToVGrid () {
			/* Why is there no modulo in CSS calc?!? */
			const lh = parseFloat(window.getComputedStyle(document.body).getPropertyValue('line-height'))
			console.log(lh)
			this.style.marginBottom = `${lh - this.getBoundingClientRect().height % lh}px`
		}

		connectedCallback () {
			this.onFrame = throttle(requestAnimationFrame)
			this.onFrame(() => this.alignToVGrid())
			window.addEventListener('resize', e => {
				this.onFrame(() => this.alignToVGrid())
			})
		}
	})
})()
