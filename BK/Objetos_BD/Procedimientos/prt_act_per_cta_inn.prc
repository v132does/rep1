CREATE OR REPLACE PROCEDURE IT.PRT_ACT_PER_CTA_INN (p_cod_canal         ta_cta_tarjetas.cod_canal%type,
                                                 p_cod_campana       ta_cta_tarjetas.cod_campana%type,
                                                 p_cod_usu_prom      ta_cta_tarjetas.cod_usu_promotor%type,
                                                 p_cod_persona       ba_personas.cod_persona%type,
                                                 p_nro_cuenta        ta_tarjetas.nro_cuenta%type,
                                                 p_nro_tarjeta       ta_tarjetas.nro_tarjeta%type,
                                                 p_nro_solicitud     ta_solicitudes.nro_solicitud%type,
                                                 p_cod_persona_ant   ba_personas.cod_persona%type,
                                                 p_cod_tip_documento ba_personas.cod_tip_documento%type,
                                                 p_nro_documento     ba_personas.nro_documento%type,
                                                 p_tip_envio         ta_solicitudes.tip_envio%type,
                                                 p_referencia        ta_solicitudes.referencia%type) IS
   v_existe varchar2(1) := 'N';
   v_embozar varchar2(50) := null;
   v_cod_oficial ge_par_dinamicos.val_parametro%type := fug_obt_pardinamico('COD_USU_OFI_INNOMINADAS');
   v_cod_ofi_matriz ba_oficinas.cod_oficina%type := fug_obt_ofi_matriz;
   v_ofi_oficial    ba_oficinas.cod_oficina%type;
   v_nom_persona    ta_cta_tarjetas.denominacion%type := fue_obt_nom_persona(p_cod_persona);
   v_error          varchar2(100);
BEGIN
  BEGIN
     IF p_cod_canal is not null OR p_cod_campana is not null OR p_cod_usu_prom is not null THEN
        UPDATE ta_cta_tarjetas
           SET cod_canal = p_cod_canal,
               cod_campana = p_cod_campana,
               cod_usu_promotor = p_cod_usu_prom
         WHERE nro_cuenta = p_nro_cuenta;
     END IF;
  END;
  ----------------------------
  v_error := 'Al insertar Cliente';
  BEGIN
    select 'S' into v_existe
      from ge_clientes
     where cod_persona = p_cod_persona;
    exception
       when no_data_found then
          INSERT INTO ge_clientes
             (cod_persona, cod_oficina, cod_usu_oficial, tip_extracto,
              residente, cod_sec_contable, cod_tip_deudor)
          VALUES
             (p_cod_persona, v_cod_ofi_matriz, v_cod_oficial, 'N', 'S', 'N', 2);
  END;
  ----------------------------
  v_error := 'Al obtener Embozado';
  v_ofi_oficial := fug_obt_ofi_oficial(p_cod_persona);
  BEGIN
     BEGIN
        SELECT REPLACE(substr(pri_nombre||' '||pri_apellido,1,20),';',' ')
          INTO v_embozar
          FROM ba_per_fisicas
         WHERE cod_persona = p_cod_persona;
     EXCEPTION
        WHEN others THEN
           v_embozar := null;
     END;
       v_error := 'Al actualizar ge_cta_cliente';
       UPDATE ge_cta_clientes
          SET cod_persona = p_cod_persona,
              cod_oficina = v_ofi_oficial
        WHERE nro_cuenta  = p_nro_cuenta
          AND cod_persona = p_cod_persona_ant;
       v_error := 'Al actualizar ta_cta_tarjetas';
       UPDATE ta_cta_tarjetas
          SET cod_oficina  = v_ofi_oficial,
              denominacion = v_nom_persona,
              estado = 'N'
        WHERE nro_cuenta  = p_nro_cuenta;
       v_error := 'Al actualizar ta_tarjetas';
       UPDATE ta_tarjetas
          SET cod_persona = p_cod_persona,
              nom_embozar = v_embozar
        WHERE nro_cuenta  = p_nro_cuenta;
       v_error := 'Al actualizar ta_solicitudes';
       UPDATE ta_solicitudes
          SET cod_persona = p_cod_persona, 
              tip_envio   = p_tip_envio, 
              referencia  = p_referencia
        WHERE nro_solicitud = p_nro_solicitud;
        
      v_error := 'Al actualizar ge_dir_envios';
      BEGIN
         UPDATE ge_dir_envios
            SET tip_envio = p_tip_envio,
                referencia = p_referencia
          WHERE cod_persona = p_cod_persona
            AND nro_cuenta = p_nro_cuenta;
         IF sql%notfound THEN
            INSERT INTO ge_dir_envios (cod_persona, tip_envio, referencia, nro_cuenta)
            VALUES (p_cod_persona, p_tip_envio, p_referencia, p_nro_cuenta);
         END IF;
      EXCEPTION
         WHEN others THEN
            null;
      END;
      
      v_error := 'Al actualizar ta_tar_nominadas';
      BEGIN
         UPDATE ta_tar_nominadas
            SET cod_persona = p_cod_persona,
                cod_tip_documento = p_cod_tip_documento,
                nro_documento = p_nro_documento
          WHERE nro_cuenta = p_nro_cuenta
            AND nro_tarjeta = p_nro_tarjeta;
         IF sql%notfound THEN
            INSERT INTO ta_tar_nominadas (nro_cuenta, nro_tarjeta, cod_persona, cod_tip_documento, nro_documento)
            VALUES (p_nro_cuenta, p_nro_tarjeta, p_cod_persona,p_cod_tip_documento, p_nro_documento);
         END IF;
      EXCEPTION
         WHEN others THEN
            null;
      END;
  END;
  COMMIT;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000,'Error en PRT_ACT_PER_CTA_INN. '||v_error);
END;
/

