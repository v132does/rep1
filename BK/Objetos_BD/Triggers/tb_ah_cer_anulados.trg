CREATE OR REPLACE TRIGGER IT.TB_AH_CER_ANULADOS
 BEFORE DELETE OR INSERT OR UPDATE
 ON AH_CER_ANULADOS
 FOR EACH ROW

DECLARE
  v_can_disponible  number(3) := 1;
  v_mon_local       ba_monedas.cod_moneda%type;
  v_cod_moneda      ba_monedas.cod_moneda%type;
  v_tip_moneda      ah_cer_grupos.tip_moneda%type;
  v_est_certificado ah_Cta_certificados.est_certificado%type;
  v_cod_cer_grupo   ah_cer_grupos.cod_cer_grupo%type;
  v_can_anulados    ah_cer_grupos.can_anulados%type;
  v_can_emitidos    ah_cer_grupos.can_emitidos%type;
  v_nro_inicial     ah_cer_grupos.nro_inicial%type;
  v_nro_final       ah_cer_grupos.nro_final%type;
begin
  If inserting then
    begin
        v_cod_moneda := :new.cod_moneda;
        v_mon_local  := PAG_GEN.FU_OBT_MON_LOCAL ;

        If v_cod_moneda = v_mon_locaL  then
           v_tip_moneda := 'L';
        else
           v_tip_moneda := 'E';
        End if;
        -- veo si debo restar o no el disponible. Solo se resta sino fue
        -- asignado el nro a ningun cda.
        begin
            select 1 /*0*/, est_certificado
              into v_can_disponible, v_est_certificado
             from ah_cta_certificados
             where nro_certificado = :new.nro_certificado
               and serie           = :new.serie
               and cod_moneda      = :new.cod_moneda
               and cod_modulo      = :new.cod_modulo
               and cod_modalidad   = :new.cod_modalidad;
            if v_est_certificado not in ('E','C') then
              raise_application_error(-20002,'Error: Estado del Certificado ya no permite anulacion');
            end if;
        exception
           when no_data_found then
              v_can_disponible := 0 /*1*/;
        end;
        /*
        || DYDMR-408 Inconvenientes con CDA - SPI 3206
        || xpy0038 - 21/05/2014
        */
        --- Se obtiene el código del grupo
        Select max(cod_cer_grupo)
          into v_cod_cer_grupo
          from ah_cer_grupos
         where :new.nro_certificado between nro_inicial and nro_final
           and serie         = :new.serie
           and cod_modulo    = :new.cod_modulo
           and cod_modalidad = :new.cod_modalidad
           and tip_moneda    = v_tip_moneda;
        if v_cod_cer_grupo is null then
           raise_application_error(-20000,'No existe Codigo de Certificado del Grupo');
        end if;
        --- Se obtiene el número inicial y final de la serie
        Select nro_inicial, nro_final
          into v_nro_inicial, v_nro_final
          from ah_cer_grupos
         where cod_cer_grupo = v_cod_cer_grupo
           and serie         = :new.serie
           and cod_modulo    = :new.cod_modulo
           and cod_modalidad = :new.cod_modalidad
           and tip_moneda    = v_tip_moneda;
        if v_nro_inicial is null then
           raise_application_error(-20000,'No existe Numero inicial para el Codigo de Certificado del Grupo '
                                       || v_cod_cer_grupo);
        end if;
        if v_nro_final is null then
           raise_application_error(-20000,'No existe Numero final para el Codigo de Certificado del Grupo '
                                       || v_cod_cer_grupo);
        end if;
        --- Se obtiene la cantidad de certificados emitidos
        select count(1)
          into v_can_emitidos
          from ah_cta_certificados t
         where serie           = :new.serie
           and nro_certificado >= v_nro_inicial
           and nro_certificado <= v_nro_final
           and cod_modulo      = :new.cod_modulo
           and cod_modalidad   = :new.cod_modalidad
           and cod_moneda      = :new.cod_moneda
           /*
           || DYDMR-732 SPI 3851 - Cartones CD no vizualizados en el Inventario - SC 4900
           || xpy0038 - 29/07/2014
           || Disminuye incorrectamente la cantidad de emitidos
           */
           and not exists (select 1
                             from ah_cer_anulados a
                            where a.nro_cuenta = t.nro_cuenta
                              and a.nro_certificado = t.nro_certificado);
        --- Se obtiene la cantidad de certificados anulados
        select count(1)
          into v_can_anulados
          from ah_cer_anulados
         where serie           = :new.serie
           and nro_certificado >= v_nro_inicial
           and nro_certificado <= v_nro_final
           and cod_modulo      = :new.cod_modulo
           and cod_modalidad   = :new.cod_modalidad
           and cod_moneda      = :new.cod_moneda;
        v_can_anulados := nvl(v_can_anulados,0) + 1; --se cuenta el actual
        -- actualizo el grupo
        update ah_cer_grupos
            set can_anulados    = nvl(v_can_anulados,0),
                can_disponibles = nvl(cantidad,0) - (nvl(v_can_emitidos,0) + nvl(v_can_anulados,0))+ nvl(v_can_disponible,0), --- Modificado para dar solucion al issue --> DYDMR-3224  
                can_emitidos = nvl(v_can_emitidos,0) - nvl(v_can_disponible,0)
                               /*decode(v_can_disponible,0,1,0)*/
          where serie         = :new.serie
            and tip_moneda    = v_tip_moneda
            and cod_modulo    = :new.cod_modulo
            and cod_modalidad = :new.cod_modalidad
            and :new.nro_certificado between nro_inicial and nro_final
            and cod_cer_grupo = v_cod_cer_grupo;
    exception
        when others then
           raise_application_error(-20000,sqlerrm);
    end;
  Elsif deleting then
    -- si se borra un anulado
     v_cod_moneda := :old.cod_moneda;
     v_mon_local  := PAG_GEN.FU_OBT_MON_LOCAL ;
     If v_cod_moneda = v_mon_locaL  then
        v_tip_moneda := 'L';
     else
        v_tip_moneda := 'E';
     End if;
     update ah_cer_grupos
        set can_anulados = nvl(can_anulados,0) - 1,
            can_disponibles = nvl(can_disponibles,0) + 1,
            estado          = decode(estado,'T','A','E','A',estado),
            ult_nro_emitido = decode(sign(:old.nro_certificado-nvl(ult_nro_emitido,nro_inicial-1)),
                                     1, ult_nro_emitido,  -- positivo, no se cambia
                                     :old.nro_certificado -1) -- es negativo, se cambia
      where serie         = :old.serie
        and tip_moneda    = v_tip_moneda
        and cod_modulo    = :old.cod_modulo
        and cod_modalidad = :old.cod_modalidad
        and :old.nro_certificado between nro_inicial and nro_final
        and can_anulados > 0
        and estado not in ('S','B')
        and cod_cer_grupo =
                         (Select max(cod_cer_grupo)
                            from ah_cer_grupos
                           where serie = :old.serie
                             and tip_moneda = v_tip_moneda
                             and cod_modulo    = :old.cod_modulo
                             and cod_modalidad = :old.cod_modalidad
                             and :old.nro_certificado between nro_inicial and nro_final
                             and can_anulados > 0
                             and estado not in ('S','B')
                          );
     If sql%notfound then
        raise_application_error(-20002,'Error: Al actualizar AH_CER_GRUPOS '||sqlerrm);
     End if;
  End if;
end;
/

