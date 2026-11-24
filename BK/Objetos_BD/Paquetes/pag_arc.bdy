CREATE OR REPLACE PACKAGE BODY IT.pag_arc IS
   /* Inicializa las variables del proceso */
   PROCEDURE pr_arc_inicio IS
   BEGIN
      pag_arc.g_archivo     := NULL;
      pag_arc.g_ruta        := NULL;
      pag_arc.g_nom_archivo := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         pag_arc.pr_arc_error(99, SQLERRM);
   END pr_arc_inicio;

   /* Abrir archivo */
   FUNCTION fu_arc_abrir
   (
      p_ruta    IN VARCHAR2,
      p_archivo IN VARCHAR2,
      p_tipo    IN VARCHAR2 DEFAULT 'R'
   ) RETURN utl_file.file_type IS
      v_arch utl_file.file_type;
   BEGIN
      v_arch := utl_file.fopen(p_ruta, p_archivo, p_tipo);
      pag_arc.pr_arc_inicio;
      pag_arc.g_archivo     := v_arch;
      pag_arc.g_ruta        := p_ruta;
      pag_arc.g_nom_archivo := p_archivo;
      RETURN v_arch;
   EXCEPTION
      WHEN no_data_found THEN
         pag_arc.pr_arc_error(1);
         RETURN v_arch;
      WHEN utl_file.invalid_path THEN
         pag_arc.pr_arc_error(2);
         RETURN v_arch;
      WHEN utl_file.invalid_mode THEN
         pag_arc.pr_arc_error(3);
         RETURN v_arch;
      WHEN utl_file.invalid_filehandle THEN
         pag_arc.pr_arc_error(4);
         RETURN v_arch;
      WHEN utl_file.invalid_operation THEN
         pag_arc.pr_arc_error(5);
         RETURN v_arch;
      WHEN utl_file.read_error THEN
         pag_arc.pr_arc_error(6);
         RETURN v_arch;
      WHEN utl_file.write_error THEN
         pag_arc.pr_arc_error(7);
         RETURN v_arch;
      WHEN utl_file.internal_error THEN
         pag_arc.pr_arc_error(8);
         RETURN v_arch;
      WHEN OTHERS THEN
         pag_arc.pr_arc_error(99, SQLERRM);
         RETURN v_arch;
   END fu_arc_abrir;

   /* Obtiene una linea del archivo */
   FUNCTION fu_arc_leer(p_archivo IN utl_file.file_type DEFAULT pag_arc.g_archivo) RETURN VARCHAR2 IS
      v_lin VARCHAR2(5000);
   BEGIN
      utl_file.get_line(p_archivo, v_lin);
      RETURN v_lin;
   EXCEPTION
      WHEN no_data_found THEN
         pag_arc.pr_arc_error(1);
         RETURN v_lin;
      WHEN utl_file.invalid_path THEN
         pag_arc.pr_arc_error(2);
         RETURN v_lin;
      WHEN utl_file.invalid_mode THEN
         pag_arc.pr_arc_error(3);
         RETURN v_lin;
      WHEN utl_file.invalid_filehandle THEN
         pag_arc.pr_arc_error(4);
         RETURN v_lin;
      WHEN utl_file.invalid_operation THEN
         pag_arc.pr_arc_error(5);
         RETURN v_lin;
      WHEN utl_file.read_error THEN
         pag_arc.pr_arc_error(6);
         RETURN v_lin;
      WHEN utl_file.write_error THEN
         pag_arc.pr_arc_error(7);
         RETURN v_lin;
      WHEN utl_file.internal_error THEN
         pag_arc.pr_arc_error(8);
         RETURN v_lin;
      WHEN OTHERS THEN
         pag_arc.pr_arc_error(99, SQLERRM);
         RETURN v_lin;
   END fu_arc_leer;

   /* Escribir una linea en un fichero */
   PROCEDURE pr_arc_escribir
   (
      p_linea   IN VARCHAR2,
      p_archivo IN utl_file.file_type DEFAULT pag_arc.g_archivo
   ) IS
   BEGIN
      utl_file.put_line(p_archivo, p_linea);
   EXCEPTION
      WHEN no_data_found THEN
         pag_arc.pr_arc_error(1);
      WHEN utl_file.invalid_path THEN
         pag_arc.pr_arc_error(2);
      WHEN utl_file.invalid_mode THEN
         pag_arc.pr_arc_error(3);
      WHEN utl_file.invalid_filehandle THEN
         pag_arc.pr_arc_error(4);
      WHEN utl_file.invalid_operation THEN
         pag_arc.pr_arc_error(5);
      WHEN utl_file.read_error THEN
         pag_arc.pr_arc_error(6);
      WHEN utl_file.write_error THEN
         pag_arc.pr_arc_error(7);
      WHEN utl_file.internal_error THEN
         pag_arc.pr_arc_error(8);
      WHEN OTHERS THEN
         pag_arc.pr_arc_error(99, SQLERRM);
   END pr_arc_escribir;

   /* Cierra el archivo */
   PROCEDURE pr_arc_cerrar(p_archivo IN utl_file.file_type DEFAULT pag_arc.g_archivo) IS
      v_arch utl_file.file_type := p_archivo;
   BEGIN
      IF utl_file.is_open(v_arch) THEN
         utl_file.fclose(v_arch);
      END IF;
      pag_arc.pr_arc_inicio;
   EXCEPTION
      WHEN no_data_found THEN
         pag_arc.pr_arc_error(1);
      WHEN utl_file.invalid_path THEN
         pag_arc.pr_arc_error(2);
      WHEN utl_file.invalid_mode THEN
         pag_arc.pr_arc_error(3);
      WHEN utl_file.invalid_filehandle THEN
         pag_arc.pr_arc_error(4);
      WHEN utl_file.invalid_operation THEN
         pag_arc.pr_arc_error(5);
      WHEN utl_file.read_error THEN
         pag_arc.pr_arc_error(6);
      WHEN utl_file.write_error THEN
         pag_arc.pr_arc_error(7);
      WHEN utl_file.internal_error THEN
         pag_arc.pr_arc_error(8);
      WHEN OTHERS THEN
         pag_arc.pr_arc_error(99, SQLERRM);
   END pr_arc_cerrar;

   PROCEDURE pr_arc_pro_archivo
   (
      p_referencia VARCHAR2,
      p_directorio VARCHAR2,
      p_fecha      DATE DEFAULT SYSDATE
   ) IS
      v_cantarch     NUMBER(5) := 0;
      v_sentencia    VARCHAR2(50);
      v_linea_ini    ge_archivos.lin_inicial%TYPE;
      v_linea_fin    ge_archivos.lin_final%TYPE;
      v_nom_arc_real VARCHAR2(1000);
      v_mensaje      VARCHAR2(2000);
      v_error EXCEPTION;
      -- Utiliza este cursor para borrar los datos temporales y para procesar ---
      CURSOR tablas IS
         SELECT nom_tabla, MIN(a.nro_secuencia) secuencia, borrar
           FROM ge_arc_tablas r, ge_archivos a
          WHERE r.referencia = a.referencia
            AND r.archivo = a.archivo
            AND r.referencia = p_referencia
          GROUP BY nom_tabla, borrar
          ORDER BY MIN(a.nro_secuencia);
      ------------------------------------------------------------------
      -- este cursor es para recorrer todos los archivos de la entidad
      ------------------------------------------------------------------
      CURSOR archivos IS
         SELECT archivo, nro_secuencia, for_fecha, lin_inicial, lin_final
           FROM ge_archivos
          WHERE referencia = p_referencia
          ORDER BY nro_secuencia;
      ------------------------------------------------------------------
      -- este cursor es para recorrer todas las tablas que debe cargar
      -- cada archivo de datos leido
      ------------------------------------------------------------------
      CURSOR tab_archivos(p_nom_archivo VARCHAR2) IS
         SELECT nom_tabla
           FROM ge_arc_tablas
          WHERE referencia = p_referencia
            AND lower(archivo) LIKE ltrim(rtrim(lower(p_nom_archivo)))
          ORDER BY nro_secuencia;
   BEGIN
      -- Debe borrar los datos temporales...
      FOR t IN tablas LOOP
         IF t.borrar = 'S' THEN
            v_sentencia := 'delete from ' || t.nom_tabla;
            sql_util.ejecute_dml(v_sentencia, v_mensaje);
            IF v_mensaje IS NOT NULL THEN
               v_mensaje := 'Al borrar la tabla: ' || t.nom_tabla || '; ' || v_mensaje;
               RAISE v_error;
            END IF;
         END IF;
      END LOOP;
      -- Debe cargar los datos de los archivos....
      FOR a IN archivos LOOP
         ----------------------------------------------------------------------------
         --carga las variables para controlar el inico y fin de lectura del archivo
         v_linea_ini    := a.lin_inicial;
         v_linea_fin    := a.lin_final;
         --CRO-MB-04/03/2014: Jira CROBAN-76 (Automatización de los Archivos de Bancard).-
         v_nom_arc_real := ltrim(rtrim(REPLACE(REPLACE(a.archivo, '$', to_char(p_fecha, a.for_fecha)),
                                                                  '*', to_char(pag_cal.FU_OBT_FEC_ANT_HAB(p_fecha,7), a.for_fecha))));
         FOR b IN tab_archivos(a.archivo) LOOP
            v_cantarch := v_cantarch + 1;
            IF v_nom_arc_real IS NOT NULL THEN
               pag_arc.pr_arc_lee_archivo(p_referencia, p_directorio, v_nom_arc_real, b.nom_tabla,
                                          v_linea_ini, v_linea_fin, p_fecha);
            ELSE
               v_mensaje := 'No se ha encontrado el archivo ' || v_nom_arc_real;
               RAISE v_error;
            END IF;
         END LOOP;
      END LOOP;
      ---
      IF v_cantarch = 0 THEN
         v_mensaje := 'No se ha leido ningún archivo...';
      END IF;
   EXCEPTION
      WHEN v_error THEN
         raise_application_error(-20145, 'ERROR: ' || v_mensaje);
      WHEN OTHERS THEN
         raise_application_error(-20146,
                                 'ERROR: Al procesar la lista de archivos para ' || p_referencia ||
                                  ' en ' || p_directorio || '; ' || SQLERRM);
   END pr_arc_pro_archivo;

   /* Controla los errores del proceso de archivos */
   PROCEDURE pr_arc_error
   (
      p_nro_error IN NUMBER DEFAULT 0,
      p_men_error IN VARCHAR2 DEFAULT 'NULL'
   ) IS
   BEGIN
      IF p_nro_error = 1 THEN
         --- Fin del archivo
         utl_file.fclose(pag_arc.g_archivo);
      ELSIF p_nro_error = 2 THEN
         utl_file.fclose(pag_arc.g_archivo);
         raise_application_error(-20770, 'Directorio invalido');
      ELSIF p_nro_error = 3 THEN
         utl_file.fclose(pag_arc.g_archivo);
         raise_application_error(-20771, 'Modo invalido');
      ELSIF p_nro_error = 4 THEN
         utl_file.fclose(pag_arc.g_archivo);
         raise_application_error(-20772, 'Invalida Filehandle');
      ELSIF p_nro_error = 5 THEN
         --- Fin del archivo
         utl_file.fclose(pag_arc.g_archivo);
      ELSIF p_nro_error = 6 THEN
         utl_file.fclose(pag_arc.g_archivo);
         raise_application_error(-20773, 'Lectura errada');
      ELSIF p_nro_error = 7 THEN
         utl_file.fclose(pag_arc.g_archivo);
         raise_application_error(-20774, 'Escritura errada');
      ELSIF p_nro_error = 8 THEN
         utl_file.fclose(pag_arc.g_archivo);
         raise_application_error(-20775, 'Error interno');
      ELSE
         raise_application_error(-20800, 'ERROR. Con el archivo: ' || p_men_error);
      END IF;
   END pr_arc_error;

   PROCEDURE pr_arc_lee_archivo
   (
      p_referencia IN VARCHAR2,
      p_directorio IN VARCHAR2,
      p_archivo    IN VARCHAR2,
      p_tabla      IN VARCHAR2,
      p_linea_ini  IN NUMBER,
      p_linea_fin  IN NUMBER,
      p_fecha      IN DATE DEFAULT SYSDATE
   ) IS
      v_archivo  utl_file.file_type;
      v_buffer   VARCHAR2(4000);
      v_contador NUMBER(10);
      -- Auxiliares de conversion
      v_fecha     VARCHAR2(18);
      v_numero    VARCHAR2(38);
      v_cadena    VARCHAR2(4000);
      v_posicion  NUMBER(4);
      v_decimales VARCHAR2(3);
      -- variables para la insercion en la tabla
      t_numero    NUMBER;
      t_decimales NUMBER(10);
      -- variable que contendra el comando de insercion a ejecutar
      v_sentencia VARCHAR2(4000);
      v_separador VARCHAR2(1);
      -- Variable que contiene el separador de campos
      v_sep_campo VARCHAR2(1);
      v_pos_campo NUMBER(8) := 0;
      v_pos_final NUMBER(8);
      -- Variable para control de posición del error
      i INTEGER;
      -- Variables para control de errores
      v_mensaje VARCHAR2(2000);
      v_error EXCEPTION;
      --
      v_insert VARCHAR2(4000);
      v_borrar ge_arc_tablas.borrar%type;
      v_for_fecha ge_archivos.for_fecha%type;
      --  DYDMR-6233 03/2017 NAF - Log para seguimiento de error de datos
      v_log_nom_tabla ge_arc_campos.nom_tabla%type;
      v_log_campo ge_arc_campos.campo%type;
      
      -- cursor para recorrer la estructura del archivo definido
      CURSOR campos IS
         SELECT nro_secuencia,
                descripcion,
                tip_dato,
                longitud,
                pos_decimal,
                formato,
                nom_tabla,
                campo,
                pos_inicial,
                funcion
           FROM ge_arc_campos
          WHERE nom_tabla = ltrim(rtrim(upper(p_tabla)))
            --CRO-MB-04/03/2014: Jira CROBAN-76 (Automatización de los Archivos de Bancard).-
            AND upper(ltrim(rtrim(REPLACE(REPLACE(archivo, '$',
                                                  to_char(p_fecha,
                                                           (SELECT for_fecha
                                                               FROM ge_archivos
                                                              WHERE referencia = p_referencia
                                                                AND upper(ltrim(rtrim(REPLACE(REPLACE(archivo, '$',to_char(p_fecha, for_fecha))
                                                                                                             , '*',to_char(pag_cal.FU_OBT_FEC_ANT_HAB(p_fecha,7), for_fecha))))) =
                                                                    
                                                                    ltrim(rtrim(upper(p_archivo)))))) 
                                  
                                              ,'*',to_char(to_char(pag_cal.FU_OBT_FEC_ANT_HAB(p_fecha,7), 
                                                                   (SELECT for_fecha
                                                                     FROM ge_archivos
                                                                    WHERE referencia = p_referencia
                                                                      AND upper(ltrim(rtrim(REPLACE(REPLACE(archivo, '$',to_char(p_fecha, for_fecha))
                                                                                                                   , '*',to_char(pag_cal.FU_OBT_FEC_ANT_HAB(p_fecha,7), for_fecha))))) =
                                                                          
                                                                          ltrim(rtrim(upper(p_archivo)))))))))) =	
                ltrim(rtrim(upper(p_archivo)))
            AND referencia = ltrim(rtrim(upper(p_referencia)))
          ORDER BY nro_secuencia;
      FUNCTION lf_obt_numero(p_dato VARCHAR2) RETURN NUMBER IS
         v_nro NUMBER;
      BEGIN
         BEGIN
            IF fue_val_es_numerico(substr(p_dato, -1)) = 'N' THEN
               v_nro := translate(p_dato, 'JKLMNOPQR}', '1234567890');
               v_nro := v_nro * -1;
            ELSE
               v_nro := p_dato;
            END IF;
         EXCEPTION
            WHEN OTHERS THEN
               v_nro := 0;
         END;
         RETURN v_nro;
      END;
   BEGIN
   
      /* busco el separador de campos si tiene */
      BEGIN
         SELECT separador, for_fecha
           INTO v_sep_campo, v_for_fecha
           FROM ge_archivos a
          WHERE referencia = p_referencia
            --CRO-MB-04/03/2014: Jira CROBAN-76 (Automatización de los Archivos de Bancard).-
            AND upper(ltrim(rtrim(REPLACE(REPLACE(archivo, '$', to_char(p_fecha, a.for_fecha)),
                                                   '*', to_char(pag_cal.FU_OBT_FEC_ANT_HAB(p_fecha,7), a.for_fecha))))) =
                ltrim(rtrim(upper(p_archivo)));
      EXCEPTION
         WHEN no_data_found THEN
            v_mensaje := 'Referencia ' || p_referencia || ' no definida. Verifique!';
            RAISE v_error;
         WHEN OTHERS THEN
            v_mensaje := 'Error al buscar Referencia ' || p_referencia || ' - ' || SQLERRM;
            RAISE v_error;
      END;
      i := 0;
      /* Tiene que truncar solo si está definido  */
      BEGIN
         SELECT borrar
           INTO v_borrar
           FROM ge_arc_tablas a
          WHERE referencia = p_referencia
            --CRO-MB-04/03/2014: Jira CROBAN-76 (Automatización de los Archivos de Bancard).-
            AND upper(ltrim(rtrim(replace(REPLACE(archivo, '$', to_char(p_fecha, nvl(v_for_fecha,''))),
                                                           '*', to_char(pag_cal.FU_OBT_FEC_ANT_HAB(p_fecha,7), nvl(v_for_fecha,'')))))) =
                ltrim(rtrim(upper(p_archivo)))
            AND nom_tabla = p_tabla;
      EXCEPTION
         WHEN no_data_found THEN
            v_mensaje := 'Tabla ' || p_tabla || ' no definida. Verifique!';
            RAISE v_error;
         WHEN OTHERS THEN
            v_mensaje := 'Error al buscar Tabla ' || p_tabla || ' - ' || SQLERRM;
            RAISE v_error;
      END;
      if nvl(v_borrar,'N') = 'S' then
         sql_util.ejecute_dml('truncate table ' || p_tabla, v_mensaje);
      end if;
      IF v_mensaje IS NOT NULL THEN
         v_mensaje := v_mensaje || '; En línea: ' || to_char(v_contador);
         RAISE v_error;
      END IF;
      i := 1;
      --v_archivo := pag_arc.fu_arc_abrir( p_directorio, lower( p_archivo ) );
      v_archivo   := utl_file.fopen(p_directorio, /*lower(*/ p_archivo /*)*/, 'R');
      i           := 2;
      v_contador  := 0;
      v_insert    := NULL;
      v_posicion  := 1;
      v_separador := NULL;
      FOR c IN campos LOOP
         i := 3;
         IF v_insert IS NULL THEN
            i        := 4;
            v_insert := 'insert into ' || c.nom_tabla || '( ';
         END IF;
         i           := 5;
         v_insert    := v_insert || v_separador || ltrim(rtrim(c.campo));
         i           := 6;
         v_posicion  := v_posicion + c.longitud;
         v_separador := ',';
      END LOOP;
      i := 7;
      IF v_insert IS NULL THEN
         v_mensaje := 'La estructura del archivo ' || p_archivo || ' para la tabla ' || p_tabla ||
                      ' no ha sido definida';
         RAISE v_error;
      END IF;
      v_insert := v_insert || ' ) values( ';
      LOOP
         -- leer una linea del archivo de entrada
         i        := 8;
         v_buffer := pag_arc.fu_arc_leer(v_archivo);
         i        := 9;
         IF ltrim(rtrim(v_buffer)) IS NOT NULL THEN
            v_contador := v_contador + 1;
            -- construir la primera parte de la sentencia INSERT
            v_sentencia := NULL;
            v_posicion  := 1;
            v_separador := NULL;
            i           := 10;
            IF v_contador >= nvl(p_linea_ini, 0) AND v_contador <= nvl(p_linea_fin, v_contador) THEN
               -- completar la sentencia con los valores a insertar
               v_posicion  := 1;
               /* Si no tiene fin de linea, se le agrega para importar la última linea */
               v_pos_campo := instr(v_buffer,chr(13), 1);
               if nvl(v_pos_campo,0) = 0 then
                  v_buffer    := v_buffer || chr(13);
               end if;
               ---
               v_buffer    := REPLACE(v_buffer, chr(39), ' ');
               v_separador := NULL;
               i           := 10;
               v_pos_campo := 0;
               FOR c IN campos LOOP
                  --  DYDMR-6233 03/2017 NAF
                  v_log_nom_tabla := c.nom_tabla;
                  v_log_campo := c.campo;
                  i         := 11;
                  v_mensaje := 'Campo: ' || c.campo || ' en línea: ' || to_char(v_contador);
                  IF v_sep_campo IS NULL THEN
                     v_cadena := substr(v_buffer, c.pos_inicial, c.longitud);
                  ELSE
                     WHILE v_pos_campo < c.nro_secuencia LOOP
                        v_pos_campo := v_pos_campo + 1;
                        v_pos_final := instr(v_buffer, v_sep_campo);
                        IF v_pos_final = 0 THEN
                           v_pos_final := length(v_buffer);
                        END IF;
                        v_cadena := substr(v_buffer, 1,  v_pos_final - 1);
                        v_buffer := substr(v_buffer, v_pos_final + 1);
                     END LOOP;
                  END IF;
                  -- completar la cadena de sentencia con el valor a insertar
                  IF c.tip_dato = 'DATE' THEN
                     i       := 12;
                     v_fecha := ltrim(rtrim(v_cadena));
                     IF v_fecha IS NOT NULL AND v_fecha <> lpad('0', nvl(length(v_fecha), 0), '0') THEN
                        i           := 13;
                        v_sentencia := v_sentencia || v_separador || 'to_date( replace( ' ||
                                       chr(39) || v_fecha || chr(39) || ', ' || 'lpad( ' || chr(39) || '0' ||
                                       chr(39) || ', ' || c.longitud || ', ' || chr(39) || '0' ||
                                       chr(39) || ' ), NULL )' || ', ' || chr(39) || c.formato ||
                                       chr(39) || ' )';
                     ELSE
                        i           := 14;
                        v_sentencia := v_sentencia || v_separador || 'NULL';
                     END IF;
                  ELSIF c.tip_dato = 'NUMBER' THEN
                     i := 15;
                     IF c.campo = 'NRO_REG' THEN
                        v_numero := v_contador;
                     ELSE
                        v_numero := lf_obt_numero(ltrim(rtrim(v_cadena)));
                     END IF;
                     IF v_numero IS NOT NULL THEN
                        i           := 16;
                        v_decimales := ltrim(rtrim(c.pos_decimal));
                        IF v_decimales IS NOT NULL THEN
                           i           := 17;
                           t_decimales := 1 * (power(10, to_number(v_decimales)));
                           t_numero    := to_number(v_numero) / t_decimales;
                           i           := 18;
                        ELSE
                           i        := 19;
                           t_numero := to_number(v_numero);
                           i        := 20;
                        END IF;
                        i        := 21;
                        v_numero := to_char(t_numero);
                        IF c.funcion IS NOT NULL THEN
                           v_sentencia := v_sentencia || v_separador ||
                                          REPLACE(c.funcion, '$param', v_numero);
                        ELSE
                           v_sentencia := v_sentencia || v_separador || v_numero;
                        END IF;
                        i := 22;
                     ELSE
                        i           := 23;
                        t_numero    := NULL;
                        v_sentencia := v_sentencia || v_separador || 'NULL';
                     END IF;
                  ELSIF c.tip_dato = 'VARCHAR2' THEN
                     i        := 24;
                     v_cadena := ltrim(rtrim(v_cadena));
                     IF v_cadena IS NOT NULL THEN
                        IF c.funcion IS NOT NULL THEN
                           i           := 25;
                           v_sentencia := v_sentencia || v_separador ||
                                          REPLACE(c.funcion, '$param',
                                                  chr(39) ||
                                                   REPLACE(v_cadena, chr(39), chr(39) || chr(39)) ||
                                                   chr(39));
                        ELSE
                           i           := 26;
                           v_sentencia := v_sentencia || v_separador || chr(39) ||
                                          REPLACE(v_cadena, chr(39), chr(39) || chr(39)) || chr(39);
                        END IF;
                     ELSE
                        i           := 27;
                        v_sentencia := v_sentencia || v_separador || 'NULL';
                     END IF;
                  END IF;
                  -- aumentar el contador de posicion
                  i           := 28;
                  v_posicion  := v_posicion + c.longitud;
                  v_separador := ',';
               END LOOP;
               i           := 29;
               v_sentencia := v_sentencia || ')';
               v_mensaje   := NULL;
               -- ejecutar la sentencia SQL
               v_sentencia := v_insert || v_sentencia;
               sql_util.ejecute_dml(v_sentencia, v_mensaje);
               IF v_mensaje IS NOT NULL THEN
                  v_mensaje := v_mensaje || '; En línea: ' || to_char(v_contador);
                  RAISE v_error;
               END IF;
            END IF;
         ELSE
            RAISE no_data_found;
         END IF;
      END LOOP;
      i := 30;
      pag_arc.pr_arc_cerrar(v_archivo);
   EXCEPTION
      WHEN v_error THEN
         pag_arc.pr_arc_cerrar(v_archivo);
         --  DYDMR-6233 03/2017 NAF
         prg_act_log_procesos('PAG_ARC.PR_ARC_LEE_ARCHIVO',substr(v_log_nom_tabla ||'.'||v_log_campo,1,60) , trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), '00:00:00',substr('Error V_ERROR: ' ||
                               ' \' || p_directorio || '\' || p_archivo || ' ' || v_mensaje ,1,400));
         pag_arc.pr_arc_error(99,
                              'ITC-00' || lpad(to_char(i), 2, '0') || ': Error en leer_archivo: ' ||
                               ' ..\' || p_directorio || '\' || p_archivo || ' ' || v_mensaje || '.');
      WHEN no_data_found THEN
         pag_arc.pr_arc_cerrar(v_archivo);
        --  DYDMR-6233 03/2017 NAF
         prg_act_log_procesos('PAG_ARC.PR_ARC_LEE_ARCHIVO',substr(v_log_nom_tabla ||'.'||v_log_campo,1,60) , trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), '00:00:00',substr('Error NO_DATA_FOUND: ' ||
                               ' \' || p_directorio || '\' || p_archivo || ' ' || v_mensaje ,1,400));
      WHEN OTHERS THEN
         pag_arc.pr_arc_cerrar(v_archivo);
         --  DYDMR-6233 03/2017 NAF
         prg_act_log_procesos('PAG_ARC.PR_ARC_LEE_ARCHIVO',substr(v_log_nom_tabla ||'.'||v_log_campo,1,60) , trunc(sysdate), to_char(sysdate,'hh24:mi:ss'), '00:00:00',substr('Error WHEN OTHERS: ' ||
                               ' \' || p_directorio || '\' || p_archivo || ' ' || v_mensaje || ' ' || SQLERRM,1,400));
         pag_arc.pr_arc_error(99,
                              'ITC-00' || lpad(to_char(i), 2, '0') || ': Error en leer_archivo: ' ||
                               ' ..\' || p_directorio || '\' || p_archivo || ' ' || v_mensaje || '. ' ||
                               SQLERRM);
   END pr_arc_lee_archivo;

   PROCEDURE pr_obt_tit_columnas
   (
      p_sql          IN VARCHAR2, -- sentencia select a analizar
      p_can_columnas IN OUT NUMBER, -- cantidad de columnas leidas
      p_encabezado   IN OUT VARCHAR2
   ) IS
      -- encabezado armado
      v_can_columnas   NUMBER(4) := 1; -- cuenta la cantidad de columnas
      v_can_parentesis NUMBER(4) := 0; -- control de parentesis en la sentencia
      v_encabezado     VARCHAR2(3000) := rtrim(REPLACE(REPLACE((substr(upper(p_sql), 1,
                                                                       instr(upper(p_sql), 'FROM') - 1)),
                                                               chr(10), ' '), chr(13), ' ')) || '$';
      v_pos            NUMBER(3);
      v_ant            NUMBER(3);
      v_tit_columna    VARCHAR2(2000);
   BEGIN
      -- cuento la cantidad de columnas de la consulta
      -------------------------------------------------
      FOR i IN 1 .. length(v_encabezado) LOOP
         IF substr(v_encabezado, i, 1) = '(' THEN
            v_can_parentesis := v_can_parentesis + 1;
         ELSE
            IF substr(v_encabezado, i, 1) = ')' AND v_can_parentesis > 0 THEN
               v_can_parentesis := v_can_parentesis - 1;
            END IF;
         END IF;
         IF v_can_parentesis = 0 THEN
            IF substr(v_encabezado, i, 1) = ',' THEN
               v_encabezado   := substr(v_encabezado, 1, i - 1) || '$' ||
                                 substr(v_encabezado, i + 1);
               v_can_columnas := v_can_columnas + 1;
            END IF;
         END IF;
      END LOOP;
      p_can_columnas := v_can_columnas;
      v_ant          := 0;
      -- Leo los nombres de las columnas -------------------------------
      p_encabezado := '';
      FOR i IN 1 .. v_can_columnas LOOP
         v_pos         := instr(substr(v_encabezado, v_ant + 1), '$') + v_ant;
         v_tit_columna := ltrim(rtrim(substr(v_encabezado, (v_ant + 1), (v_pos - v_ant - 1))));
         v_ant         := instr(v_tit_columna, '"'); -- busco una comilla
         IF v_ant = 0 THEN
            v_ant := instr(v_tit_columna, ' ', -1); -- busco el primer espacio antes del separador $
         END IF;
         IF v_ant > 0 THEN
            v_tit_columna := substr(v_tit_columna, v_ant + 1); -- obtengo el titulo de la columna
         END IF;
         v_tit_columna := initcap(REPLACE(v_tit_columna, '"', '')); -- le saco las comillas
         -- encabezado
         p_encabezado := p_encabezado || '#' || v_tit_columna;
         -- guardo la posicion actual
         v_ant := v_pos;
      END LOOP;
   END pr_obt_tit_columnas;

   /* Obtiene el nombe final del archivo */
   FUNCTION fu_obt_nom_final(p_nom_archivo IN VARCHAR2) RETURN VARCHAR2 IS
      v_nom_arc_final VARCHAR2(5000);
      v_fec_proceso   DATE := pag_cal.fu_obt_fec_actual(1);
      v_hor_actual    VARCHAR2(20) := to_char(SYSDATE, 'hh24:mi:ss');
   
   BEGIN
   
      SELECT substr(p_nom_archivo, (instr(p_nom_archivo, '$') + 1)) INTO v_nom_arc_final FROM dual;
   
      IF v_nom_arc_final = 'F' THEN
         v_nom_arc_final := REPLACE(p_nom_archivo, '$F', '_') || to_char(v_fec_proceso, 'YYYYMMDD');
      ELSIF v_nom_arc_final = 'H' THEN
         v_nom_arc_final := REPLACE(p_nom_archivo, '$H', '_') || v_hor_actual;
      ELSIF v_nom_arc_final = 'FH' THEN
         v_nom_arc_final := REPLACE(p_nom_archivo, '$FH', '_') ||
                            to_char(v_fec_proceso, 'YYYYMMDD') || v_hor_actual;
      ELSE
         v_nom_arc_final := p_nom_archivo;
      END IF;
      RETURN v_nom_arc_final;
   EXCEPTION
      WHEN no_data_found THEN
         pag_arc.pr_arc_error(1);
         RETURN v_nom_arc_final;
      WHEN OTHERS THEN
         pag_arc.pr_arc_error(99, SQLERRM);
         RETURN v_nom_arc_final;
   END fu_obt_nom_final;

END pag_arc;
/

