[message_processors]
%{ for ip in mp_ip ~}
${ip} 
%{ endfor ~}


