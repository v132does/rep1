create or replace procedure it.prg_gen_aler_tra_rrhh(p_reg_snp in pas_snp.rg_msj,
                                                     p_tipo in varchar2)  is
/*
Este procedimiento valida ciertas condiciones para notificar al grupo de talento humano
por las transferencias SIPAP/SPI que reciben los funcionarios
*/
v_cod_per_beneficiario  ba_personas.cod_persona%type;
v_usu_oficial           ba_usuarios.cod_usuario%type;
v_cod_per_solicitante   ba_personas.cod_persona%type;
v_can_reg               number(5):=0;
v_nom_entidad           varchar2(200);
v_dir_notificaciones    ge_par_dinamicos.val_parametro%type:=fug_obt_pardinamico('GEN_DIR_ALE_TRANSFERENCIA');
begin
  --se obtiene el codigo de la persona beneficiaria
  v_cod_per_beneficiario:=fue_obt_cod_persona_doc(p_reg_snp.cod_tip_doc_beneficiario,p_reg_snp.nro_doc_beneficiario);

  if v_cod_per_beneficiario is not null then
       ---verifica si el beneficiario es oficial de cuentas
       select tt.cod_usuario
       into v_usu_oficial
       from ba_usuarios tt
       where tt.oficial='S'
       and tt.estado='A'
       and tt.cod_persona=v_cod_per_beneficiario;

       --se obtiene el codigo de la persona solicitante
       v_cod_per_solicitante:=fue_obt_cod_persona_doc(p_reg_snp.cod_tip_doc_solicitante,p_reg_snp.nro_doc_solicitante);

       if v_cod_per_solicitante is not null then --el solicitante esta registrado como cliente

           --verificar si el solicitante es parte de la cartera del oficial , beneficiario de la transferencia
          select count(*)
          into v_can_reg
          from ge_clientes
          where cod_persona = v_cod_per_solicitante
          and cod_usu_oficial = v_usu_oficial;

          if v_can_reg>0 then
             --enviar correo
              if p_tipo='S' then  --S sipap/spi
                
                 if p_reg_snp.cod_tip_operacion = '001' and
                    p_reg_snp.cod_sub_tip_operacion = '004' then --transf de un sub-participante
                    v_nom_entidad := it.fus_obt_nom_sub_participante(p_reg_snp.cod_swi_pte_solicitante, p_reg_snp.cod_swi_suc_solicitante);
                 else
                    v_nom_entidad := it.fug_obt_nom_snp_participante(p_reg_snp.cod_swi_pte_solicitante);
                 end if;
      
                  it_mail.mail( fug_obt_dir_correo,
                               v_dir_notificaciones,
                               'Transferencia SIPAP/SPI recibida en cuenta de oficial',
                               'El oficial de cuentas '||fue_obt_nom_persona(v_cod_per_beneficiario)||' con '||fue_obt_tip_doc_abreviatura(p_reg_snp.cod_tip_doc_beneficiario)
                                                   ||' Nro. '||p_reg_snp.nro_doc_beneficiario
                                                   || chr(10) ||'Ha recibido una transferencia SIPAP/SPI cuyos datos se detallan: '
                                                   || chr(10) ||'Nro. Referencia: '||p_reg_snp.nro_referencia
                                                   || chr(10) ||'Cuenta Beneficiaria: '||p_reg_snp.nro_cta_beneficiario
                                                   || chr(10) ||'Entidad Solicitante: '||v_nom_entidad
                                                   || chr(10) ||'Cuenta Solicitante: '||p_reg_snp.nro_cta_solicitante
                                                   || chr(10) ||'Doc. Solicitante: '||fue_obt_tip_doc_abreviatura(p_reg_snp.cod_tip_doc_solicitante)||' Nro. '||p_reg_snp.nro_doc_solicitante
                                                   || chr(10) ||'Nombre Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante)
                                                   || chr(10) ||'Fecha/Hora Recepcion: '||to_char(p_reg_snp.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Monto: '||p_reg_snp.cod_moneda||' '||ltrim(rtrim(to_char(p_reg_snp.monto,'999,999,999,999,999.99'))));
                
              else  -- I - Interna
                  it_mail.mail( fug_obt_dir_correo,
                                v_dir_notificaciones,
                                'Transferencia interna recibida en cuenta de oficial',
                                'El oficial de cuentas '||fue_obt_nom_persona(v_cod_per_beneficiario)||' con '||fue_obt_tip_doc_abreviatura(p_reg_snp.cod_tip_doc_beneficiario)
                                                   ||' Nro. '||p_reg_snp.nro_doc_beneficiario
                                                   || chr(10) ||'Ha recibido una transferencia interna cuyos datos se detallan: '
                                                   || chr(10) ||'Nro. transaccion: '||p_reg_snp.nro_referencia
                                                   || chr(10) ||'Cuenta Beneficiaria: '||p_reg_snp.nro_cta_beneficiario
                                                   || chr(10) ||'Cuenta Solicitante: '||p_reg_snp.nro_cta_solicitante
                                                   || chr(10) ||'Doc. Solicitante: '||fue_obt_tip_doc_abreviatura(p_reg_snp.cod_tip_doc_solicitante)||' Nro. '||p_reg_snp.nro_doc_solicitante
                                                   || chr(10) ||'Nombre Solicitante: '||fue_obt_nom_persona(v_cod_per_solicitante)
                                                   || chr(10) ||'Fecha/Hora Recepcion: '||to_char(p_reg_snp.fec_recepcion, 'DD/MM/YYYY HH24:MI:SS')
                                                   || chr(10) ||'Monto: '||p_reg_snp.cod_moneda||' '||ltrim(rtrim(to_char(p_reg_snp.monto,'999,999,999,999,999.99'))));
              end if;
          end if;
       end if;
  end if;
exception
    when others then
         null;
end;
/

