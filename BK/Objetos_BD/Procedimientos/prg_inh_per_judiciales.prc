CREATE OR REPLACE PROCEDURE it.prg_inh_per_judiciales IS

  v_cod_persona GE_PER_INHIBIDAS.COD_PERSONA%type;
  v_nro_orden   GE_PER_INHIBIDAS.Nro_Orden%type;
  v_cantidad    integer;
  v_cod_causa   GE_CAUSALES.COD_CAUSA%type := fug_obt_pardinamico('COD_CAU_INHIBICION');

  cursor c_personas is
    select upper(trim(t.primer_nombre) || ' ' || trim(t.segundo_nombre) || ' ' ||
                 trim(t.primer_apellido) || ' ' || trim(t.segundo_apellido)) nombre_completo,
           decode(t.tipo_documento, 'RUC', 'J', 'F') tipo,
           d.cod_tip_documento, 
           t.nro_documento,
           246 pais,
           t.causal,
           t.comentario,
           upper(t.primer_nombre) pri_nombre,
           upper(t.segundo_nombre) seg_nombre,
           upper(t.primer_apellido) pri_apellido,
           upper(t.segundo_apellido) seg_apellido
      from TM_PER_JUDICIALES t, ba_tip_documentos d
     where upper(trim(t.tipo_documento)) = d.abreviatura
       and nvl(t.procesado, 'N') = 'N'

    ;

BEGIN
  BEGIN
    PRE_INI_APLICACION;
    PAE_CNF.G_COD_MODULO := 1;
  END;

  for r_cup in c_personas loop

    Select count(*)
      into v_cantidad
      from ba_personas t
     where t.nro_documento = r_cup.nro_documento
       and t.cod_tip_documento = r_cup.cod_tip_documento;

    if v_cantidad = 0 then
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
           'DATOS DE OFICIOS JUDICIALES',
           sysdate);

      exception
        when others then
          raise_application_error(-20000,
                                  'Error insert ba_personas ' || sqlerrm);
      end;

      if nvl(r_cup.tipo, 'X') = 'F' then
        begin
          INSERT INTO ba_per_fisicas
            (cod_persona,
             pri_nombre,
             pri_apellido,
             seg_nombre,
             seg_apellido)
          VALUES
            (v_cod_persona,
             substr(r_cup.pri_nombre, 1, 30),
             substr(r_cup.pri_apellido, 1, 30),
             substr(r_cup.seg_nombre, 1, 30),
             substr(r_cup.seg_apellido, 1, 30));

        exception
          when others then
            raise_application_error(-20000,
                                    'Error insert ba_per_fisicas ' ||
                                    sqlerrm);
        end;
      end if;
      if nvl(r_cup.tipo, 'X') = 'J' then
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
      
   else
      begin
        Select t.cod_persona
          into v_cod_persona
          from ba_personas t
         where t.nro_documento = r_cup.nro_documento
           and t.cod_tip_documento = r_cup.cod_tip_documento;
      exception
        when others then
          raise_application_error(-20000,
                                  'Error en buscar cod_persona ' || sqlerrm);
      end;

    end if; -- finaliza la insercion en ba_personas
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
         referencia,
         DETALLE,
         ESTADO)
      values
        (v_cod_persona,
         v_nro_orden,
         v_cod_causa,
         trunc(sysdate),
         'TM_PER_JUDICIALES',
         upper(substr(r_cup.causal, 1, 80)),
         r_cup.comentario,
         'I');
    exception
      when others then
        raise_application_error(-20000,
                                'Error insert GE_PER_INHIBIDAS ' || sqlerrm);
    end;
    begin
       update tm_per_judiciales j
         set j.procesado = 'S',
             j.fecha = sysdate
       where j.nro_documento=r_cup.nro_documento
         and j.causal= r_cup.causal
         and j.comentario =r_cup.comentario
        ;

    end;
  end loop;
exception
  when others then
    raise_application_error(-20000,
                            'Error prg_inh_per_judiciales' || sqlerrm);
END;
/
