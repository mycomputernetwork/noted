# Enable from milestone 2, once there is an interface to protect. Note that the
# importmap tag is inline, so the nonce directives below are required for it to
# execute — turn both on together or not at all.
#
# Rails.application.configure do
#   config.content_security_policy do |policy|
#     policy.default_src :self
#     policy.font_src    :self
#     policy.img_src     :self, :data, :blob
#     policy.object_src  :none
#     policy.script_src  :self
#     policy.style_src   :self
#     policy.connect_src :self
#   end
#
#   config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
#   config.content_security_policy_nonce_directives = %w[script-src style-src]
# end
