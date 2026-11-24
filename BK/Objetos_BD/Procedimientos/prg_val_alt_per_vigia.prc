create or replace procedure it.prg_val_alt_per_vigia(v_cod_persona   in number,
                                                     v_nom_completo  in varchar2,
                                                     v_nro_documento in varchar2,
                                                     v_parecida      in out varchar2) is
  v_referencia varchar2(4000);
  v_detalle	   varchar2(4000);
  v_resultado  varchar2(4000);
begin
  IF fug_obt_pardinamico('IND_VAL_VIGIA') = 'S' THEN
    -- VERIFICAR POR NRO DE CEDULA  Y POR NOMBRE
    v_referencia :=   it.fug_obt_rep_vigia(v_nom_completo, v_nro_documento);

    IF rtrim(ltrim(v_referencia)) <> '0.0' THEN
      BEGIN
        SELECT substr(detalle, 1, 2000)
          INTO v_detalle
          FROM ge_vigia_det d
         WHERE d.cod_vigia = substr(rtrim(ltrim(v_referencia)), 1, instr(v_referencia, '.') - 1);
        v_resultado := 'SI';
      EXCEPTION
        WHEN no_data_found THEN
          v_detalle := v_referencia;
          v_resultado := 'NO'; --Mensaje bloqueante para no generar el workflow
        WHEN OTHERS THEN
          v_detalle := v_referencia;
          v_resultado := 'NO'; --Mensaje bloqueante para no generar
      END;

      IF nvl(v_resultado, 'NO') = 'SI' THEN
        it.prc_ins_per_inhibidos(v_cod_persona,
                                 1,
                                 nvl(fug_obt_pardinamico('PER_COINCIDENCIA'),333),
                                 SYSDATE,
                                 NULL,
                                 'Persona de compra de cartera con coincidencias en listas',
                                 'I', --'D',
                                 'INS',
                                 v_detalle,
                                 '7'); -- Se agrega para identificar el cod_circuito

         IF paw_cir.fu_ini_circuito(7, v_cod_persona, v_cod_persona) <> 0 THEN
           raise_application_error(-20002, 'Error al generar WorkFlow por % Coincidencia Vigia. cod_persona: '||v_cod_persona);
         ELSE
           v_parecida := v_resultado; --SI
         END IF;
      END IF;
   END IF;

 ELSE
   v_parecida := 'NO';
 END IF;
END;
/
