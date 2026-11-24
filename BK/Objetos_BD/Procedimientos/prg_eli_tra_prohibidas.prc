CREATE OR REPLACE PROCEDURE IT.PRG_ELI_TRA_PROHIBIDAS
 IS
V_EXISTE NUMBER(8);
V_FEC_ACTUAL DATE;
v_dir_cor_varios varchar2(200);
cursor tran_prob is
    select gec.cod_modulo cod_modulo,
           gec.cod_modalidad cod_modalidad,
           gec.nro_cuenta nro_cuenta,a.fec_vencimiento fec_vencimiento,
           a.cod_transaccion cod_transaccion,
           a.rowid fila, cli.cod_usu_oficial, ofi.cod_usu_encargado
      from ba_oficinas ofi, ge_clientes cli, ge_cta_clientes gec, ge_tra_prohibidas a
      where trunc(a.fec_vencimiento) <  v_fec_actual
        and gec.nro_cuenta = a.nro_cuenta
        and gec.relacion = 'P'
        and cli.cod_persona = gec.cod_persona
        and ofi.cod_oficina = cli.cod_oficina
        and a.nro_cuenta is not null;
begin
  v_fec_actual := PAG_CAL.FU_OBT_FEC_ACTUAL(1);
  for tra in tran_prob loop
    delete ge_tra_prohibidas
      where rowid = tra.fila;
    --Ver si tiene otras transacciones personalizadas
  	select count(1)
	    into v_existe
	    from ge_tra_prohibidas
	   where nro_cuenta = tra.nro_cuenta;
    If v_existe = 0 then
        If tra.cod_modalidad = 31 then -- Av.
           update ah_cta_vistas set tra_prohibida = 'N'
             where nro_cuenta = tra.nro_cuenta;
        elsif tra.cod_modalidad in (32,37,38) then -- Plazo
           update ah_cta_plazos set tra_prohibida = 'N'
             where nro_cuenta = tra.nro_cuenta;
        elsif tra.cod_modalidad in (33,34,36) then --CDA
           update ah_cta_certificados set tra_prohibida = 'N'
             where nro_cuenta = tra.nro_cuenta;
        elsif tra.cod_modalidad = 41 then  --Cta.Ctes.
            update cc_cta_corrientes set tra_prohibida = 'N'
             where nro_cuenta = tra.nro_cuenta;
        end if;
    End if;
    -- envio mail al oficial y al encargado de la sucursal
    v_dir_cor_varios := null;
    if tra.cod_usu_oficial is not null then
       v_dir_cor_varios := fug_obt_dir_mail_usu(tra.cod_usu_oficial);
    end if;
    if tra.cod_usu_encargado is not null then
       if v_dir_cor_varios is not null then
          v_dir_cor_varios := v_dir_cor_varios || ';'; -- separador
       end if;   
       v_dir_cor_varios := fug_obt_dir_mail_usu(tra.cod_usu_encargado);
    end if;   
    if v_dir_cor_varios is not null then
       -- hay direccion de envio, por lo que envio el mail
       it_mail.mail(fug_obt_dir_correo,
                    v_dir_cor_varios,
                    'Transacción Prohibida vencida y eliminada',
                    'Se ha eliminado en forma automatica la Transacción Prohibida con el codigo '||
                    tra.cod_modulo||'-'||tra.cod_modalidad||'-'||tra.cod_transaccion||' asociada a la Cuenta '||tra.nro_cuenta||' cuyo vencimiento '||
                    ' estaba definido para el dia '||to_char(tra.fec_vencimiento,'dd/mm/yyyy')||'.'||
                    chr(10)||'Atentamente.');
    end if;  
  end loop;
end;
/

