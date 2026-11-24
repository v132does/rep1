CREATE OR REPLACE PROCEDURE IT.PRG_VAL_OPERATIVAS_CIERRE is
  cursor c_cda_no_fondeado is
  select c.nro_cuenta, c.denominacion, c.fec_apertura, c.estado, c.serie, c.nro_certificado,
         c.beneficiario, c.cod_moneda, c.capital, c.usu_insercion, c.fec_insercion, c.usu_modificacion, c.fec_modificacion
    from it.ah_cta_certificados c
   where c.estado = 'A'
     and rownum < 11;

  cursor c_cup_cda_no_emitido is
  select distinct a.nro_cuenta, a.cod_moneda, a.denominacion, a.fec_apertura, a.capital,
         a.fec_insercion, a.usu_insercion
    from it.ah_cta_certificados a, it.ah_cupones c
   where a.nro_cuenta = c.nro_cuenta
     and a.estado = 'N'
     and c.estado = 'C'
     and a.nro_cta_credito is null
   order by a.nro_cuenta;

  cursor c_md_mov_no_confirmados is
  select d.nro_cuenta, d.denominacion, d.cod_persona, d.cod_modalidad, m.descripcion desc_modalidad, d.cod_oficina,
         d.fec_inicio, d.fec_vencimiento, d.cod_moneda, d.monto, d.fec_insercion, d.usu_insercion
    from it.md_cta_documentos d, it.ge_modalidades m
   where d.estado = 'S'
     and d.cod_modulo = m.cod_modulo
     and d.cod_modalidad = m.cod_modalidad
   order by d.nro_cuenta;

  v_can_cda_nofondeados number;
  v_nro_cuenta varchar2(2000);
  v_error varchar2(5000);
  v_mail_usu ba_usuarios.dir_correo%type;
  v_mail_adicional ge_par_dinamicos.val_parametro%type := nvl(fug_obt_pardinamico('DIR_COR_VAL_OPE_CIERRE'), fug_obt_pardinamico('CAM_MAR_DIR_EP'));
  v_mails varchar2(200);
begin
  ----CDA's no fondeados
  select nvl(count(*),0)
    into v_can_cda_nofondeados
    from it.ah_cta_certificados c
   where c.estado = 'A';

  if v_can_cda_nofondeados < 11 then 
    for x in c_cda_no_fondeado loop
       v_error := null;
       v_error := v_error||'Favor regularizar CDA no fondeado.'||chr(13)||'Cuenta: '||x.nro_cuenta||' - Denominacion: '||x.denominacion;
       v_error := v_error||' - Fec_apert: '||to_char(x.fec_apertura,'dd/mm/yyyy')||' - Serie: '||x.serie||' - Nro_Certif: '||x.nro_certificado;
       v_error := v_error||' - Cod_moneda: '||x.cod_moneda||' - Capital: '||trim(to_char(x.capital,'999G999G999G999G999D99'))||' - Usu_insercion: '||x.usu_insercion;
       v_error := v_error||' - Fec_insercion: '||to_char(x.fec_insercion,'dd/mm/yyyy hh24:mi:ss')||chr(13)||chr(13);
       v_error := trim(v_error);

       ---Enviar por cada uno de los CDA's un mail al que cargó y otro a implementacionITGF

       v_mail_usu := it.fug_obt_dir_mail_usu(x.usu_insercion);
       v_mails := null;
       if v_mail_usu is not null then
          v_mails := v_mail_usu || ',' || v_mail_adicional;
       else
          v_mails := v_mail_usu || v_mail_adicional;
       end if;

       if trim(v_error) is not null then
         begin
          it_mail.mail (fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                        v_mails, 
                        'Problemas en el Cierre - Validacion Operativa CDA''s No Fondeados '||pag_cal.fu_obt_fec_actual(1),
                        v_error);
         exception
           when others then
             raise_application_error(-20001, 'Error al enviar correo. '||sqlerrm);
         end;
       end if;

    end loop;
  else
    
    for x in c_cda_no_fondeado loop
       if v_nro_cuenta is null then
          v_nro_cuenta := x.nro_cuenta;
       else
          v_nro_cuenta := v_nro_cuenta ||', '|| x.nro_cuenta;
       end if;
    end loop;
        
    v_error := null;
    v_error := 'Existen '||to_char(v_can_cda_nofondeados)||' de CDA No Fondeados. Verificar. '||chr(13)||
               'Se detallara hasta 10 Cuentas: '||v_nro_cuenta;
    v_error := trim(v_error);

    v_mails := null;
    
    if v_mail_usu is not null then
       v_mails := v_mail_usu || ',' || v_mail_adicional;
    else
       v_mails := v_mail_usu || v_mail_adicional;
    end if;

    if trim(v_error) is not null then
       begin
         it_mail.mail (fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                       v_mails,
                      'Problemas en el Cierre - Validacion Operativa CDA''s No Fondeados '||pag_cal.fu_obt_fec_actual(1),
                      v_error);
        exception
           when others then
             raise_application_error(-20001, 'Error al enviar correo. '||sqlerrm);
        end;
     end if;
  
  end if;  
  ---CDA fondeado, pero cupón no emitido
  for x in c_cup_cda_no_emitido loop

     v_error := null;
     v_error := v_error||'Favor regularizar CDA con Cupones no Emitidos.'||chr(13)||'Cuenta: '||x.nro_cuenta||' - Denominacion: '|| x.denominacion;
     v_error := v_error||' - Fec_apert: '||to_char(x.fec_apertura,'dd/mm/yyyy')||' - Cod_moneda: '||x.cod_moneda||' - Capital: '||trim(to_char(x.capital,'999G999G999G999G999D99'));
     v_error := v_error||' - Usu_insercion: '||x.usu_insercion||' - Fec_insercion: '||to_char(x.fec_insercion,'dd/mm/yyyy hh24:mi:ss')||chr(13)||chr(13);
     v_error := trim(v_error);

     ---Enviar por cada uno de los CDA's un mail al que cargó y otro a implementacionITGF
     v_mail_usu := it.fug_obt_dir_mail_usu(x.usu_insercion);

     v_mails := null;
     if v_mail_usu is not null then
        v_mails := v_mail_usu || ',' || v_mail_adicional;
     else
        v_mails := v_mail_usu || v_mail_adicional;
     end if;

     if trim(v_error) is not null then
       begin
        it_mail.mail (fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                      v_mails,
                      'Problemas en el Cierre - CDA''s con Cupones no Emitidos '||pag_cal.fu_obt_fec_actual(1),
                      v_error);
       exception
         when others then
           raise_application_error(-20002, 'Error al enviar correo. '||sqlerrm);
       end;
     end if;

  end loop;

  ---Movimientos de Mesa de Dinero no confirmados
  for x in c_md_mov_no_confirmados loop
     v_error := null;
     v_error := v_error||'Favor regularizar Movimiento de Mesa de Dinero no confirmado.'||chr(13)||'Cuenta: '||x.nro_cuenta||' - Denominacion: '||x.denominacion||' - Modalidad: '||x.desc_modalidad;
     v_error := v_error||' - Fec_inicio: '||to_char(x.fec_inicio,'dd/mm/yyyy')||' - Fec_vto: '||to_char(x.fec_vencimiento,'dd/mm/yyyy');
     v_error := v_error||' - Cod_moneda: '||x.cod_moneda||' - Monto: '||trim(to_char(x.monto,'999G999G999G999G999D99'));
     v_error := v_error||' - Usu_insercion: '||x.usu_insercion||' - Fec_insercion: '||to_char(x.fec_insercion,'dd/mm/yyyy hh24:mi:ss')||chr(13)||chr(13);
     v_error := trim(v_error);

     ---Enviar por cada uno de los CDA's un mail al que cargó y otro a implementacionITGF
     v_mail_usu := it.fug_obt_dir_mail_usu(x.usu_insercion);

     v_mails := null;
     if v_mail_usu is not null then
        v_mails := v_mail_usu || ',' || v_mail_adicional;
     else
        v_mails := v_mail_usu || v_mail_adicional;
     end if;

     if trim(v_error) is not null then
       begin
        it_mail.mail (fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET'),
                      v_mails,
                      'Problemas en el Cierre - Movim. de Mesa de Dinero no Confirmados '||pag_cal.fu_obt_fec_actual(1),
                      v_error);
       exception
         when others then
           raise_application_error(-20003, 'Error al enviar correo. '||sqlerrm);
       end;
     end if;

  end loop;
exception
  when others then
    raise_application_error(-20000, 'Error al ejecutar procedimiento:'||sqlerrm);
end;
/

