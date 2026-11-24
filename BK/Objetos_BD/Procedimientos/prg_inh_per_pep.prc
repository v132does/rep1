CREATE OR REPLACE PROCEDURE it.prg_inh_per_pep IS

  v_cod_persona  GE_PER_INHIBIDAS.COD_PERSONA%type;
  v_nro_orden    GE_PER_INHIBIDAS.Nro_Orden%type;
  v_per_fondo    GE_PER_INHIBIDAS.COD_PERSONA%type;
  v_per_inhibido GE_PER_INHIBIDAS.COD_PERSONA%type;
  v_cod_causa    GE_CAUSALES.COD_CAUSA%type := fug_obt_pardinamico('COD_CAU_PEP');

  cursor c_personas is
    select upper(trim(t.nombre) || ' ' || trim(t.apellido)) nombre_completo,
           decode(t.tip_documento, 'RUC', 'J', 'F') tipo,
           decode(t.tip_documento, 'RUC', '6', 'CRC', '8', '1') cod_tip_documento,
           t.nro_documento,
           246 pais,
           t.comentario,
           t.causal,
           upper(t.nombre) Nombre,
           upper(t.apellido) Apellido
      from TM_CLIENTE_PEP t;

BEGIN
  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
  END;

  for r_cup in c_personas loop
    begin
      Select t.cod_persona
        into v_cod_persona
        from ba_personas t
       where t.nro_documento = r_cup.nro_documento
         and t.cod_tip_documento = r_cup.cod_tip_documento;
    exception
      when others then
        v_cod_persona := 0;
    end;

    begin
      Select t.cod_persona
        into v_per_inhibido
        from GE_PER_INHIBIDAS t
       where t.cod_persona = v_cod_persona
         and t.cod_causa = v_cod_causa;
    exception
      when others then
        v_per_inhibido := 0;
    end;

    begin
      Select t.cod_persona
        into v_per_fondo
        from CR_INF_FONDOS t
       where t.cod_persona = v_cod_persona;
    exception
      when others then
        v_per_fondo := 0;
    end;

    if v_cod_persona = 0 then
      SELECT s_cod_persona.nextval INTO v_cod_persona FROM dual;
      begin
        INSERT INTO ba_personas
          (cod_persona,
           nom_completo,
           tipo,
           cod_tip_documento,
           nro_documento,
           cod_pais,
           cod_rub_primario,
           cod_actividad,
           est_verificacion,
           obs_verificacion,
           fec_verificacion)
        VALUES
          (v_cod_persona,
           r_cup.nombre_completo,
           r_cup.tipo,
           r_cup.cod_tip_documento,
           r_cup.nro_documento,
           r_cup.pais,
           749911,
           fug_obt_cod_actividad(749911),
           'V',
           'DATOS DE CLIENTES PEP',
           sysdate);
      exception
        when others then
          raise_application_error(-20000, 'Error insert ba_personas ' || sqlerrm);
      end;
    IF r_cup.tipo = 'F' then
    if fug_obt_nombre(r_cup.nombre, 1) is not null or fug_obt_nombre(r_cup.apellido, 1) is not null then
      begin
        INSERT INTO ba_per_fisicas
          (cod_persona,
           pri_nombre,
           pri_apellido,
           seg_nombre,
           seg_apellido)
        VALUES
          (v_cod_persona,
           fug_obt_nombre(r_cup.nombre, 1),
           fug_obt_nombre(r_cup.apellido, 1),
           fug_obt_nombre(r_cup.nombre, 2),
           fug_obt_nombre(r_cup.apellido, 2)
          );
      exception
        when others then
          raise_application_error(-20000, 'Error insert ba_per_fisicas ' || sqlerrm);
      end;
     end if;
     END IF;
     IF r_cup.tipo = 'J' then
      begin
        INSERT INTO ba_per_juridicas
          (cod_persona,
           raz_social,
           nom_comercial)
        VALUES
          (v_cod_persona,
           r_cup.nombre_completo,
           r_cup.nombre_completo
          );
      exception
        when others then
          raise_application_error(-20000, 'Error insert ba_per_juridicas ' || sqlerrm);
      end;
     end if;

      Select nvl(max(t.nro_orden), 0) + 1
        into v_nro_orden
        from GE_PER_INHIBIDAS t
       where t.cod_persona = v_cod_persona;

      begin
        insert into GE_PER_INHIBIDAS
          (COD_PERSONA,
           NRO_ORDEN,
           COD_CAUSA,
           FEC_INICIO,
           ORIGEN,
           REFERENCIA,
           DETALLE,
           ESTADO)
        values
          (v_cod_persona,
           v_nro_orden,
           v_cod_causa,
           trunc(sysdate),
           'TM_CLIENTE_PEP',
           r_cup.causal,
           r_cup.comentario,
           'I');
      exception
        when others then
          raise_application_error(-20000, 'Error insert GE_PER_INHIBIDAS ' || sqlerrm);
      end;

      begin
        insert into CR_INF_FONDOS
          (COD_PERSONA, PEP, PEP_OBSERVACION)
        values
          (v_cod_persona, 'S',r_cup.comentario);
      exception
        when others then
          raise_application_error(-20000, 'Error insert CR_INF_FONDOS ' || sqlerrm);
      end;
    else
      if v_per_inhibido = 0 then
        Select nvl(max(t.nro_orden), 0) + 1
          into v_nro_orden
          from GE_PER_INHIBIDAS t
         where t.cod_persona = v_cod_persona;

        begin
          insert into GE_PER_INHIBIDAS
            (COD_PERSONA,
             NRO_ORDEN,
             COD_CAUSA,
             FEC_INICIO,
             ORIGEN,
             DETALLE,
             ESTADO)
          values
            (v_cod_persona,
             v_nro_orden,
             v_cod_causa,
             trunc(sysdate),
             'TM_CLIENTE_PEP',
             r_cup.comentario,
             'I');
        exception
          when others then
            raise_application_error(-20000, 'Error insert GE_PER_INHIBIDAS ' || sqlerrm);
        end;
      end if;
      if v_per_fondo = 0 then
        begin
          insert into CR_INF_FONDOS
            (COD_PERSONA, PEP, PEP_OBSERVACION)
          values
            (v_cod_persona, 'S',r_cup.comentario);
        exception
          when others then
            raise_application_error(-20000, 'Error insert CR_INF_FONDOS ' ||  sqlerrm);
        end;
      else
        update CR_INF_FONDOS 
           set pep = 'S',
           pep_observacion = r_cup.comentario
         where cod_persona = v_cod_persona;
      end if;

    end if;
  end loop;
exception
  when others then
    raise_application_error(-20000, 'Error prg_inh_per_pep' || sqlerrm);
END;
/
