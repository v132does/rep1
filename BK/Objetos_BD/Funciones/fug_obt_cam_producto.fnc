CREATE OR REPLACE FUNCTION IT.FUG_OBT_CAM_PRODUCTO (p_nro_cuenta ge_cuentas.nro_cuenta%TYPE)
   RETURN typ_listacondiciones IS
   v_cod_modulo           ba_modulos.cod_modulo%TYPE;
   v_cod_modalidad        ge_modalidades.cod_modalidad%TYPE;
   v_sentencia            VARCHAR2(2000);
   r_tip_condiciones      typ_condiciones := typ_condiciones;
   r_tip_listacondiciones typ_listacondiciones := typ_listacondiciones();
   --v_registro             NUMBER := 0;
   v_existe               BOOLEAN := FALSE;
   rg_cuentas             ge_cuentas%ROWTYPE;
   -- tabla bulk collect
   TYPE registro IS RECORD(
      valor VARCHAR2(300));
   TYPE tregistro IS TABLE OF registro;
   bdatos tregistro;
   -- tabla bulk collect
   TYPE detalle IS RECORD(
      valor VARCHAR2(300));
   TYPE tdetalle IS TABLE OF detalle;
   bdatosdet tdetalle;
   -- cursor de condiciones
   CURSOR c_condiciones IS
      SELECT nom_tabla,
             nom_campo,
             etiqueta,
             origen,
             nom_tab_origen,
             nom_cam_origen,
             dominio,
             cod_programa,
             nro_orden,
             par_ampliado
        FROM ge_cam_productos
       WHERE cod_modulo = v_cod_modulo
         AND (cod_modalidad = v_cod_modalidad OR cod_modalidad IS NULL)
       ORDER BY nro_orden;
BEGIN
   -- obtener los datos de la cuenta
   SELECT * INTO rg_cuentas FROM ge_cuentas WHERE nro_cuenta = p_nro_cuenta;
   v_cod_modulo    := rg_cuentas.cod_modulo;
   v_cod_modalidad := rg_cuentas.cod_modalidad;
   FOR i IN c_condiciones LOOP
      -- asignar la etiqueta al campo etiqueta del tipo de dato condición.
      r_tip_condiciones.etiqueta := i.etiqueta;
      -- consultar el valor para la tabla y el campo indicado
      v_sentencia := ' select ' || i.nom_campo || ' from ' || i.nom_tabla || ' where nro_cuenta=''' ||
                     p_nro_cuenta || '''';
      BEGIN
         EXECUTE IMMEDIATE v_sentencia BULK COLLECT
            INTO bdatos;
         -- si no encontró datos
         IF bdatos.count = 0 THEN
            r_tip_condiciones.valor := 'No Encontrado';
            GOTO fin;
         END IF;
         -- recorro los resultados de la consulta principal
         FOR j IN bdatos.first .. bdatos.last LOOP
            --validar que tipo de acción a tomar
            IF i.origen = 'N' THEN
               -- no se debe ejecutar ninguna acción posterior
               r_tip_condiciones.valor := bdatos(j).valor;
               -- para asociar todos los valores
               r_tip_listacondiciones.extend;
               r_tip_listacondiciones(r_tip_listacondiciones.count) := r_tip_condiciones;
               v_existe := TRUE;
            ELSIF i.origen = 'T' THEN
               -- el valor del campo es un código y se debe buscar su descripción
               -- se debe buscar en una tabla maestra.
               v_sentencia := ' select ' || i.nom_cam_origen || ' from ' || i.nom_tab_origen ||
                              ' where ' || i.nom_campo || '=''' || bdatos(j).valor || '''';
               EXECUTE IMMEDIATE v_sentencia BULK COLLECT
                  INTO bdatosdet;
               -- si no encontró datos
               IF bdatosdet.count = 0 THEN
                  r_tip_condiciones.valor := 'No Encontrado';
                  GOTO fin;
               END IF;
               -- recorro los resultados del detalle
               FOR k IN bdatosdet.first .. bdatosdet.last LOOP
                  r_tip_condiciones.valor := bdatosdet(k).valor;
                  -- para asociar todos los valores
                  r_tip_listacondiciones.extend;
                  r_tip_listacondiciones(r_tip_listacondiciones.count) := r_tip_condiciones;
               END LOOP;
               v_existe := TRUE;
            ELSIF i.origen = 'R' THEN
               -- el valor del campo es un código y su descripción
               -- se debe buscar en una referencia general.
               v_sentencia := ' select significado' || ' from ba_cod_referencias' ||
                              ' where dominio =''' || i.dominio || ''' and val_minimo =''' || bdatos(j)
                             .valor || '''';
               EXECUTE IMMEDIATE v_sentencia
                  INTO r_tip_condiciones.valor;
               -- ajuste para asociar los valores
               r_tip_listacondiciones.extend;
               r_tip_listacondiciones(r_tip_listacondiciones.count) := r_tip_condiciones;  
               v_existe := TRUE;             
            ELSIF i.origen = 'F' THEN
               -- el valor del campo es un código y para obtener su descripción
               -- se debe buscar  en una función.
               IF nvl(i.par_ampliado, 'N') = 'S' THEN
                  v_sentencia := ' select ' || i.cod_programa || '(''' || p_nro_cuenta || ''',''' || bdatos(j)
                                .valor || ''')' || ' from dual';
               ELSE
                  v_sentencia := ' select ' || i.cod_programa || '(''' || p_nro_cuenta || ''')' ||
                                 ' from dual';
               END IF;
               EXECUTE IMMEDIATE v_sentencia
                  INTO r_tip_condiciones.valor;
               IF r_tip_condiciones.valor IS NULL THEN
                  r_tip_condiciones.valor := 'No Encontrado';
               END IF;
               r_tip_listacondiciones.extend;
               r_tip_listacondiciones(r_tip_listacondiciones.count) := r_tip_condiciones; 
               v_existe := TRUE;
            END IF;
         END LOOP;
      EXCEPTION
         WHEN no_data_found THEN
            r_tip_condiciones.valor := 'No Encontrado';
         WHEN OTHERS THEN
            r_tip_condiciones.valor := 'Error (' || SQLERRM || ')';
      END;
      <<fin>>
      --v_registro := v_registro + 1;
      IF v_existe = FALSE THEN
        r_tip_listacondiciones.extend;
        r_tip_listacondiciones(r_tip_listacondiciones.count) := r_tip_condiciones;
      END IF;
      v_existe := FALSE;
      --dbms_output.put_line(r_tip_condiciones.etiqueta || ': ' || r_tip_condiciones.valor);
   END LOOP;
   -- retorna la lista de resultados
   dbms_output.put_line('Cantidad Registros: ' || r_tip_listacondiciones.count);
   RETURN(r_tip_listacondiciones);
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE <= -20000 THEN
         RAISE;
      ELSE
         raise_application_error(-20000, 'en fug_obt_cam_producto - ' || SQLERRM);
      END IF;
END;
/

