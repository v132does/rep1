CREATE OR REPLACE PROCEDURE IT.PRG_ELI_RET_PERSONALIZADAS
 IS
V_EXISTE NUMBER(8);
V_FEC_ACTUAL DATE;
v_dir_cor_varios varchar2(200);
cursor retenciones is
    select ger.nro_cuenta,ger.fec_vencimiento,ger.cod_retencion,gec.cod_modalidad,
           ger.rowid fila, cli.cod_usu_oficial, ofi.cod_usu_encargado
      from ba_oficinas ofi, ge_clientes cli, ge_cta_clientes gec, ge_ret_cuentas ger
     where trunc(ger.fec_vencimiento) <  v_fec_actual
       and gec.nro_cuenta = ger.nro_cuenta
       and gec.relacion = 'P'
       and cli.cod_persona = gec.cod_persona
       and ofi.cod_oficina = cli.cod_oficina
       and ger.nro_cuenta is not null;
begin
  v_fec_actual := PAG_CAL.FU_OBT_FEC_ACTUAL(1);
  for ret in retenciones loop
    delete ge_ret_cuentas
     where rowid = ret.fila;
    v_existe := 0;
  	--Ver si tiene otras retenciones personalizadas
  	select count(1)
	  into v_existe
	  from ge_ret_cuentas
	 where nro_cuenta = ret.nro_cuenta;
	 If v_existe = 0 then
        If ret.cod_modalidad = 31 then -- Av.
           update ah_cta_vistas set ret_personalizada = 'N'
             where nro_cuenta = ret.nro_cuenta;
        elsif ret.cod_modalidad = 41 then  --Cta.Ctes.
            update cc_cta_corrientes set ret_personalizada = 'N'
             where nro_cuenta = ret.nro_cuenta;
        end if;
    End if;
    -- envio mail al oficial y al encargado de la sucursal
    v_dir_cor_varios := null;
    if ret.cod_usu_oficial is not null then
       v_dir_cor_varios := fug_obt_dir_mail_usu(ret.cod_usu_oficial);
    end if;
    if ret.cod_usu_encargado is not null then
       if v_dir_cor_varios is not null then
          v_dir_cor_varios := v_dir_cor_varios || ';'; -- separador
       end if;   
       v_dir_cor_varios := fug_obt_dir_mail_usu(ret.cod_usu_encargado);
    end if;   
    if v_dir_cor_varios is not null then
       -- hay direccion de envio, por lo que envio el mail
       it_mail.mail(fug_obt_dir_correo,
                    v_dir_cor_varios,
                    'Retencion personalizada vencida y eliminada',
                    'Se ha eliminado en forma automatica la retencion personalizada con el codigo '||
                    ret.cod_retencion||' asociada a la Cuenta '||ret.nro_cuenta||' cuyo vencimiento '||
                    ' estaba definido para el dia '||to_char(ret.fec_vencimiento,'dd/mm/yyyy')||'.'||
                    chr(10)||'Atentamente.');
    end if;
  end loop;
end;
/

