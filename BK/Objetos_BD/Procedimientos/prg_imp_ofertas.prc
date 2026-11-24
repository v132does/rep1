CREATE OR REPLACE PROCEDURE IT.PRG_IMP_OFERTAS(p_cod_persona IN ba_personas.cod_persona%TYPE,
                                          p_producto  in bw_ofe_clientes.producto%TYPE,
                                          p_mensaje   in bw_ofe_clientes.mensaje%TYPE default null,
                                          p_resultado out bw_ofe_clientes.mensaje%TYPE) IS
  rg_bcocl   bw_cnf_ofe_clientes%ROWTYPE;
  v_sql      VARCHAR2(2000);
  v_result   VARCHAR2(2000);
  v_etiqueta VARCHAR2(300);
  v_valor    VARCHAR2(300);
  v_msj_general varchar2(3000):= fug_obt_pardinamico('MSJ_INI_CAN_DIGITAL');
  v_mensaje   varchar2(3000);
  -- valor obtenido en el select principal
  CURSOR c_lista(p_select IN VARCHAR2) IS
     SELECT column_value linea
       FROM
      TABLE(fug_obt_tab_registro(REPLACE(p_select, ';', ',')));
  -- decomposicion de campos del select anterior
  CURSOR c_campos(p_select IN VARCHAR2) IS
     SELECT column_value linea, rownum
       FROM
      TABLE(fug_obt_tab_registro(REPLACE(p_select, '=', ',')));
BEGIN
  ---*****INICIO DE PROCESO PRINCIPAL *************+
  -- Verificamos si recibimos o no mensaje, sino recibimos, buscamos de par_dinamico es estandar
  v_mensaje:= null;
  if p_mensaje is null then
    --Si no se carga mensaje , se toma del parametro dinamico general
    if v_msj_general is not null then
      p_resultado:= v_msj_general;
    else
      p_resultado:= 'No se encuentra parametrizado mensaje general';
    end if;
  else
     v_mensaje := p_mensaje;
     -- se verifica si hay una configuracion de template para el producto
      begin
        SELECT *
          INTO rg_bcocl
          FROM bw_cnf_ofe_clientes oc
         WHERE oc.producto = p_producto;
      EXCEPTION
            WHEN no_data_found THEN
              raise_application_error(-20000, 'No esta configurado la parametria para: '||p_producto);
      END;

      -- se arma el query a ejecutar
      v_sql := 'SELECT '||rg_bcocl.campos||' FROM '||rg_bcocl.tabla;
      IF rg_bcocl.filtro IS NOT NULL THEN
        --Verificamos si la persona existe en la tabla

        v_sql := v_sql || ' WHERE ' || REPLACE(rg_bcocl.filtro, '%s', p_cod_persona);
      END IF;
      -- se ejecuta el query
      BEGIN
         EXECUTE IMMEDIATE v_sql INTO v_result;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
           raise_application_error(-20000, 'No se encuentra la persona en la tabla destino, codigo: '||p_cod_persona);
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Configuracion incorrecta para '||p_producto ||' '||SQLERRM);
      END;
      -- armo los parametros a cambiar en mensaje
      FOR lista IN c_lista(v_result) LOOP
        FOR datos IN c_campos(lista.linea) LOOP
          IF datos.rownum = 1 THEN
            v_etiqueta := datos.linea;
          ELSE
            v_valor := datos.linea;
          END IF;
        END LOOP;
        v_mensaje:= REPLACE(v_mensaje, v_etiqueta, v_valor);
      END LOOP;
      p_resultado:= v_mensaje;

 end if;
EXCEPTION
  WHEN no_data_found THEN
     NULL;
END;
/

