create or replace procedure it.prc_pro_lin_sobregiros(p_estado in varchar2, p_nro_secuencia in number) is

begin
  if p_estado not in ('A','R') then
     raise_application_error(-20000,'Error. Los Estados a procesar solo pueden ser A-Aprobado o R-Rechazado. Verifique');
  end if;
  
  --Actualizar Estado--
  update cc_lin_sobregiros h
      set h.estado = decode(p_estado,'R','I',p_estado),
          h.observacion = decode(p_estado,'R',null,h.observacion),
          h.cod_usu_autoriza = decode(p_estado,'R',null,h.cod_usu_autoriza),
          h.niv_aprobacion = decode(p_estado,'R',null,h.niv_aprobacion)
    where ((h.nro_secuencia = p_nro_secuencia) or (h.nro_sec_padre = p_nro_secuencia))
      and h.estado = 'X';
  
  if p_estado = 'A' then --Aprobado--
     prc_ins_his_sobregiro(p_nro_secuencia);
  end if;
  
exception
  when others then
    raise_application_error(-20000,'Error en prc_pro_lin_sobregiros: '||sqlerrm);
end;
/

