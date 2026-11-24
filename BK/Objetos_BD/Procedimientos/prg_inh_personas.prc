CREATE OR REPLACE PROCEDURE IT.prg_inh_personas IS
  v_cod_persona GE_PER_INHIBIDAS.COD_PERSONA%type;
  v_nro_orden   GE_PER_INHIBIDAS.Nro_Orden%type;
  v_cantidad    integer;
  v_existe      varchar2(1) := 'N';

  cursor c_personas is
    select upper(trim(t.primer_nombre) || ' ' || trim(t.segundo_nombre) || ' ' ||
                 trim(t.primer_apellido) || ' ' || trim(t.segundo_apellido)) nombre_completo,
           decode(t.tipo_documento, 'RUC', 'J', 'F') tipo,
           d.cod_tip_documento,
           t.nro_documento,
           246 pais,
           t.causal,
           t.cod_causa,
           t.comentario,
           upper(t.primer_nombre) pri_nombre,
           upper(t.segundo_nombre) seg_nombre,
           upper(t.primer_apellido) pri_apellido,
           upper(t.segundo_apellido) seg_apellido
      from TM_PER_INHIBIDAS t, ba_tip_documentos d
     where upper(trim(t.tipo_documento)) = d.abreviatura
       and nvl(t.procesado, 'N') = 'N';

BEGIN
  PRE_INI_APLICACION;
  PAE_CNF.G_COD_MODULO := 1;

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
           'DATOS DE PERSONAS INHIBIDAS',
           sysdate);

      exception
        when others then
          raise_application_error(-20000,'Error insert ba_personas ' || sqlerrm);
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
            raise_application_error(-20000, 'Error insert ba_per_fisicas ' ||sqlerrm);
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
          raise_application_error(-20000,'Error en buscar cod_persona ' || sqlerrm);
      end;

    end if; -- finaliza la insercion en ba_personas
   
   SELECT nvl(MAX(t.nro_orden), 0) + 1
     INTO v_nro_orden
     FROM ge_per_inhibidas t
    WHERE t.cod_persona = v_cod_persona;
   
   --verificar si existe con la misma causa antes de insertar
   BEGIN
     SELECT distinct('S')
       INTO v_existe
       FROM ge_per_inhibidas t
      WHERE t.cod_persona = v_cod_persona
        AND t.cod_causa = r_cup.cod_causa
        AND t.estado = 'I'
        and t.fec_inicio = trunc(sysdate)
        AND rownum = 1;
   EXCEPTION
     WHEN no_data_found THEN
       v_existe := 'N';
   END;

    BEGIN
      IF v_existe = 'N' THEN
        INSERT INTO ge_per_inhibidas
          (cod_persona,
           nro_orden,
           cod_causa,
           fec_inicio,
           origen,
           referencia,
           detalle,
           estado)
        VALUES
          (v_cod_persona,
           v_nro_orden,
           r_cup.cod_causa,
           trunc(SYSDATE),
           'CUMPLIMIENTO',
           upper(substr(r_cup.causal, 1, 80)),
           fug_eli_car_invalidos(r_cup.comentario),
           'I');
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,'Error insert GE_PER_INHIBIDAS ' || SQLERRM);
    END;
    
    begin
       update tm_per_inhibidas j
         set j.procesado = 'S',
             j.fecha = sysdate
       where j.nro_documento=r_cup.nro_documento
         and j.causal= r_cup.causal
         and j.comentario =r_cup.comentario
         and j.cod_causa = r_cup.cod_causa;
    end;
  end loop;
exception
  when others then
    raise_application_error(-20000,'Error prg_inh_personas' || sqlerrm);
END;
/
