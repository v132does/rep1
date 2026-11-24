create or replace TRIGGER IT.TA_PR_GARANTIAS
 BEFORE INSERT OR UPDATE
 ON PR_GARANTIAS
 FOR EACH ROW
declare
  cursor c_hipotecarias(p_nro_garantia number) is
     select nro_inscripcion, cod_ent_seguro, val_seguro, nro_poliza,
            fec_vto_seguro, fec_ini_seguro, fec_vencimiento,
            nro_finca
       from pr_gar_hipotecarias a
      where a.nro_garantia = p_nro_garantia;

  cursor c_vehiculos(p_nro_garantia number) is
     select nro_inscripcion, cod_ent_seguro, val_seguro, nro_poliza,
            fec_vto_seguro, fec_ini_seguro, fec_vencimiento, movil,
            nro_contrato
       from pr_gar_vehiculos a
      where a.nro_garantia = p_nro_garantia;

  v_cod_modulo           ba_modulos.cod_modulo%type;
  v_msj_nro_registro     varchar2(40) := '';
  v_val_activo           ge_est_cuentas.activo%type;

BEGIN
  IF :new.estado != :old.estado then
     :new.fec_ult_utilizacion := null;
      if ((:old.estado <> 'V' or :new.estado <> 'C') 
        --wa: 29/07/2014 Para que no valide en el proceso de cierre
        and (nvl(pae_cnf.g_programa, 'X') <> 'GPPROFIN')) then
        if fup_obt_nom_tab_anexa(:new.cod_garantia)= 'PR_GAR_HIPOTECARIAS' then
           for hi in c_hipotecarias(:new.nro_garantia)loop
              v_msj_nro_registro := ' Nro. de Finca: '||hi.nro_finca;
              if hi.nro_inscripcion is null then
                 raise_application_error(-20000, 'El Nro. de Inscripción debe cargarse.'||v_msj_nro_registro);
              end if;

              if hi.cod_ent_seguro is not null then
                 if hi.fec_ini_seguro is null then
                    raise_application_error(-20000, 'La Fecha Inicio de Seguro debe cargarse.'||v_msj_nro_registro);
                 end if;
                 if hi.fec_vto_seguro is null then
                    raise_application_error(-20000, 'La Fecha Vencimiento de Seguro debe cargarse.'||v_msj_nro_registro);
                 end if;
                 if hi.val_seguro is null then
                    raise_application_error(-20000, 'El valor del Seguro debe cargarse.'||v_msj_nro_registro);
                 end if;
                 if hi.nro_poliza is null then
                    raise_application_error(-20000, 'El Nro. de Póliza debe cargarse.'||v_msj_nro_registro);
                 end if;
              else
                 if hi.fec_ini_seguro is not null then
                    raise_application_error(-20000,
                                            'La Fecha Inicio de Seguro no puede cargarse sin Aseguradora.'||v_msj_nro_registro);
                 end if;
                 if hi.fec_vto_seguro is not null then
                    raise_application_error(-20000,
                                            'La Fecha Vencimiento de Seguro no puede cargarse sin Aseguradora.'||v_msj_nro_registro);
                 end if;
                 if hi.val_seguro is not null then
                    raise_application_error(-20000, 'El Valor de Seguro no puede cargarse sin Aseguradora.'||v_msj_nro_registro);
                 end if;
                 if hi.nro_poliza is not null then
                    raise_application_error(-20000, 'El Nro. de Póliza no puede cargarse sin Aseguradora.'||v_msj_nro_registro);
                 end if;
              end if;
           end loop;
         end if;
      
        if fup_obt_nom_tab_anexa(:new.cod_garantia)= 'PR_GAR_VEHICULOS' then
           for ve in c_vehiculos(:new.nro_garantia)loop
              v_msj_nro_registro := ' Nro. de Contrato: '||ve.nro_contrato;
              if ve.movil = 'S' then
                 if ve.nro_inscripcion is null then
                   raise_application_error(-20000, 'El Nro. de Inscripción debe cargarse.'||v_msj_nro_registro);
                 end if;
              end if;

              if ve.cod_ent_seguro is not null then
                 if ve.fec_ini_seguro is null then
                    raise_application_error(-20000, 'La Fecha Inicio de Seguro debe cargarse.'||v_msj_nro_registro);
                 end if;
                 if ve.fec_vto_seguro is null then
                    raise_application_error(-20000, 'La Fecha Vencimiento de Seguro debe cargarse.'||v_msj_nro_registro);
                 end if;
                 if ve.val_seguro is null then
                    raise_application_error(-20000, 'El Valor de Seguro debe cargarse.'||v_msj_nro_registro);
                 end if;
                 IF ve.nro_poliza IS NULL THEN
                    raise_application_error(-20000, 'El Nro. de Póliza debe cargarse.'||v_msj_nro_registro);
                 end if;
              else
                 if ve.fec_ini_seguro is not null then
                    raise_application_error(-20000, 'La Fecha Inicio de Seguro no puede cargarse sin Aseguradora.'||v_msj_nro_registro);
                 end if;
                 if ve.fec_vto_seguro is not null then
                    raise_application_error(-20000, 'La Fecha Vencimiento de Seguro no puede cargarse sin Aseguradora.'||v_msj_nro_registro);
                 end if;
                 if ve.val_seguro is not null then
                    raise_application_error(-20000, 'El Valor de Seguro no puede cargarse sin Aseguradora.'||v_msj_nro_registro);
                 end if;
                 if ve.nro_poliza is not null then
                    raise_application_error(-20000, 'El Nro. de Póliza no puede cargarse sin Aseguradora.'||v_msj_nro_registro);
                 end if;
              end if;
           end loop;
        end if;
     end if;
     -------------------------------------------------------------------------
     if fup_obt_nom_tab_anexa(:new.cod_garantia)= 'PR_GAR_CASH' then
       begin
         select distinct t.cod_modulo
           into v_cod_modulo
           from pr_gar_cash c,
                pr_cas_tipos t
          where c.cod_cas_tipo = t.cod_cas_tipo
            and c.nro_garantia = :new.nro_garantia;
       exception
         when others then
              raise_application_error(-20000,'Gar: '||:NEw.nro_garantia||' '||SQLERRM);
       end;
       ---agrego validacion para tener el estado de la cuenta
       BEGIN
            select g_est_c.activo
            into v_val_activo
            from ge_est_cuentas g_est_c, ge_cuentas ge, pr_gar_cash pr_gar_c
            where g_est_c.cod_modulo=ge.cod_modulo
            and g_est_c.cod_modalidad=ge.cod_modalidad
            and g_est_c.estado=ge.estado
            and ge.nro_cuenta = pr_gar_c.nro_cta_referencia
            and pr_gar_c.nro_garantia = :new.nro_garantia
			and rownum=1;
        exception
          when others then
              raise_application_error(-20000,'Gar: '||:NEw.nro_garantia||' '||SQLERRM);
       end;
       ------------------------------------------------------------------------------
       if v_cod_modulo is not null then
         if :new.estado = 'C' then  --sólo al confirmar, afecta al cash
         --Si se cambia el estado y se vuelve a confirmar verificar que la garantia no se haya confirmado antes--
         --DYDMR-3873--09/09/2016--  
            DECLARE
               v_nro_garantia pr_garantias.nro_garantia%TYPE;
            BEGIN
               SELECT g.nro_garantia
                 into v_nro_garantia
                 FROM pr_gar_cash g,
                      pr_cas_tipos t,
                      ge_bloqueos b
                WHERE g.cod_cas_tipo = t.cod_cas_tipo
                  and g.nro_cta_referencia = b.nro_cuenta
                  and g.nro_documento = b.nro_documento
                  and g.nro_garantia = :new.nro_garantia;
             EXCEPTION
                WHEN no_data_found THEN
                  pap_gar.PR_PRO_GAR_CASH(:new.nro_garantia, null, 1, null, 6,
                                          61, :new.cod_oficina, :new.cod_moneda,:new.mto_aplicado,'C');
                WHEN OTHERS THEN
                  raise_application_error(-20000, 'Confirm. Garantia ' || SQLERRM);
             END;
         elsif :old.estado in ('C','V') and :new.estado = 'N' and v_val_activo <> 'N' then --sólo al cancelar, desafecta el cash
                                                                                           --se agrega para que no tenga en cuenta las
                                                                                           --cuentas canceladas v_val_activo <> 'N'
           pap_gar.PR_PRO_GAR_CASH(:new.nro_garantia, null, 1, null, 6,
                                 61, :new.cod_oficina, :new.cod_moneda,:new.mto_aplicado,'R');
         end if;
       end if;
     end if;
  End if;
  ------------------------------------------------------
  --Verifico si la garantia posee operaciones vigentes, para cancelar la garantia  - MODIF EC - 15/09/2010
  If PAP_GAR.FU_OBT_CTA_VIN_GARANTIAS(:new.nro_garantia, :new.cod_garantia) is not null and --DYDMR-10177 , se agrega el parametro cod_garantia
     :new.estado = 'N' then
     raise_application_error(-20000,'Existen operacion(es) vigente(s) vinculadas a la Garantía.'||SQLERRM);
  End if;
  ------------------------------------------------------
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,SQLERRM);
END;
