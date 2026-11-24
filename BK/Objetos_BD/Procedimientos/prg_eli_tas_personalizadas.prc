CREATE OR REPLACE PROCEDURE IT.PRG_ELI_TAS_PERSONALIZADAS
 IS
V_FEC_ACTUAL DATE;
V_EXISTE NUMBER(8);
V_DIR_COR_VARIOS VARCHAR2(4000);
V_TAS_PER_DIA_AVI_VTO_TASAS NUMBER;
V_FEC_HAB_INI DATE; -- Fecha Inicio hábil del vencimiento
V_FEC_HAB_FIN DATE; -- Fecha Fin hábil del vencimiento
V_COD_USU_SUPERVISOR BA_USUARIOS.COD_USU_SUPERVISOR%TYPE;--Usuario Oficial 
cursor tasas is
    select get.cod_persona fpersona ,get.nro_cuenta,get.fec_vencimiento,get.cod_tasa,gec.cod_modalidad,
           get.rowid fila, cli.cod_usu_oficial, ofi.cod_usu_encargado,
           get.cod_persona, 'F' tipo 
      from ba_oficinas ofi, ge_clientes cli, ge_cta_clientes gec,ge_tas_fechas get
     where ((trunc(get.fec_vencimiento) > v_fec_hab_ini and trunc(get.fec_vencimiento) <= v_fec_hab_fin)
           OR(trunc(get.fec_vencimiento) < v_fec_actual))
       and gec.nro_cuenta(+) = get.nro_cuenta
       and gec.relacion(+) = 'P'
       and nvl(gec.cod_persona, get.cod_persona) = cli.cod_persona
       and ofi.cod_oficina = cli.cod_oficina
       and (get.nro_cuenta is not null or get.cod_persona is not null)
     union
    select get.cod_persona,get.nro_cuenta,get.fec_vencimiento,get.cod_tasa,gec.cod_modalidad,
           get.rowid fila, cli.cod_usu_oficial, ofi.cod_usu_encargado,
           get.cod_persona, 'V' tipo
      from ba_oficinas ofi, ge_clientes cli, ge_cta_clientes gec,ge_tas_rangos get
     where ((trunc(get.fec_vencimiento) > v_fec_hab_ini and trunc(get.fec_vencimiento) <= v_fec_hab_fin)
           OR(trunc(get.fec_vencimiento) < v_fec_actual))
       and gec.nro_cuenta(+) = get.nro_cuenta
       and gec.relacion(+) = 'P'
       and nvl(gec.cod_persona, get.cod_persona) = cli.cod_persona
       and ofi.cod_oficina = cli.cod_oficina
       and (get.nro_cuenta is not null or get.cod_persona is not null);       
begin
  v_fec_actual := pag_cal.fu_obt_fec_actual(1);
  v_tas_per_dia_avi_vto_tasas :=  fug_obt_pardinamico('TAS_PER_DIA_AVI_VTO_TASAS'); 
	v_fec_hab_ini := fug_obt_fec_sig_habil(v_fec_actual,null,v_tas_per_dia_avi_vto_tasas-1);
  v_fec_hab_fin := pag_cal.fu_obt_fec_sig_hab(v_fec_hab_ini,null,1);
  for tas in tasas loop
    if trunc(tas.fec_vencimiento) < v_fec_actual then
       if tas.tipo = 'F' then
          delete ge_tas_fechas
           where rowid = tas.fila;
       else
          delete ge_tas_rangos
           where rowid = tas.fila;        
       end if;  
       v_existe := 0;
  	   --Ver si tiene otras tasas personalizadas
       if tas.nro_cuenta is not null then
          select count(1)
            into v_existe
            from ge_tas_fechas
           where nro_cuenta = tas.nro_cuenta;
          If v_existe = 0 then
             select count(1)
               into v_existe
               from ge_tas_rangos
              where nro_cuenta = tas.nro_cuenta;
          end if;    
          If v_existe = 0 then
             If tas.cod_modalidad = 31 then -- Av.
                update ah_cta_vistas set tas_personalizada = 'N'
                 where nro_cuenta = tas.nro_cuenta;
             elsif tas.cod_modalidad in (32,37,38) then  --Plazo.
                update ah_cta_plazos set tas_personalizada = 'N'
                 where nro_cuenta = tas.nro_cuenta;
             elsif tas.cod_modalidad in (33,34,36) then -- cda tif
                update ah_cta_certificados set tas_personalizada = 'N'
                 where nro_cuenta = tas.nro_cuenta;
             elsif tas.cod_modalidad = 41 then  --Cta.Ctes.
                update cc_cta_corrientes set tas_personalizada = 'N'
                 where nro_cuenta = tas.nro_cuenta;
             end if;
          End if;
       elsif tas.cod_persona is not null then
          select count(1)
            into v_existe
            from ge_tas_fechas
           where cod_persona = tas.cod_persona;
          If v_existe = 0 then
             select count(1)
               into v_existe
               from ge_tas_rangos
              where cod_persona = tas.cod_persona;
          end if;           
          If v_existe = 0 then
             update ba_personas set tas_personalizada = 'N'
              where cod_persona = tas.cod_persona;   
          end if;                
      end if;
    else
       -- envio mail al oficial y al supervisor 
       v_dir_cor_varios := null;
       if tas.cod_usu_oficial is not null then
          v_dir_cor_varios := fug_obt_dir_mail_usu(tas.cod_usu_oficial);
       end if;
       if v_dir_cor_varios is not null then
          v_dir_cor_varios := v_dir_cor_varios || ';'; -- separador
       end if; 
       v_cod_usu_supervisor := fue_obt_sup_usuario(tas.cod_usu_oficial);
       if v_cod_usu_supervisor is not null then  
          v_dir_cor_varios := v_dir_cor_varios||fug_obt_dir_mail_usu(v_cod_usu_supervisor);
       end if;
       if v_dir_cor_varios is not null then
          -- hay direccion de envio, por lo que envio el mail
          if tas.nro_cuenta is not null then
             it_mail.mail(fug_obt_dir_correo,
                          v_dir_cor_varios,
                          'Tasa o tarifa personalizada vencida y eliminada',
                          'Se procederá a eliminar en forma automática en el periodo de '||V_TAS_PER_DIA_AVI_VTO_TASAS||
                          ' días, la tasa o tarifa personalizada con el código '||
                          tas.cod_tasa||' / '||fug_obt_des_tasa(tas.cod_tasa)||' asociada a la Cuenta '||tas.nro_cuenta||' / '||fue_obt_nom_persona(fug_obt_cli_principal(tas.nro_cuenta))||' cuyo vencimiento '||
                          ' está definido para el día '||to_char(tas.fec_vencimiento,'dd/mm/yyyy')||'.'||
                          chr(10)||'Atentamente.');
          elsif nvl(tas.fpersona,tas.cod_persona) is not null and tas.nro_cuenta is null then
             it_mail.mail(fug_obt_dir_correo,
                          v_dir_cor_varios,
                          'Tasa o tarifa personalizada vencida y eliminada',
                          'Se procederá a eliminar en forma automática en el periodo de '||V_TAS_PER_DIA_AVI_VTO_TASAS||
                          ' días, la tasa o tarifa personalizada con el código '||
                          tas.cod_tasa||' / '||fug_obt_des_tasa(tas.cod_tasa)||' asociada a la Persona '||nvl(tas.fpersona,tas.cod_persona)||' / '||fue_obt_nom_persona(nvl(tas.fpersona,tas.cod_persona))||' cuyo vencimiento '||
                          ' está definido para el día '||to_char(tas.fec_vencimiento,'dd/mm/yyyy')||'.'||
                          chr(10)||'Atentamente.');         
          end if;                     
       end if;    
    end if;
  end loop;
end;
/

