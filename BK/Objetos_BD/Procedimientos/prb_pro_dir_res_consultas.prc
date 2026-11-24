CREATE OR REPLACE PROCEDURE IT.prb_pro_dir_res_consultas IS

   --cursor de las consultas dinamicas
   CURSOR sqls IS
      SELECT a.det_sql, a.descripcion, a.cod_consulta
        FROM ba_consultas a
       WHERE a.cod_consulta IN
             ('BCRUBSAL', 'BCRUBTRA', 'BCRUBAUT', 'BCRUBNAT', 'BCRUBAFE', 'BCRUBSUS');

   v_retorno   NUMBER := 0;
   v_mensaje   VARCHAR2(4000);
   v_plsql     ba_consultas.det_sql%TYPE;
   v_filtro    LONG;
   v_remitente ge_par_generales.dir_correo%TYPE := fug_obt_dir_mail_usu(USER);
   v_destino   ge_par_generales.dir_correo%TYPE;

   --funcion para ejecutar consulta
   FUNCTION fn_execute(v_sql IN ba_consultas.det_sql%TYPE) RETURN NUMBER IS
      v_count NUMBER := 0;
   BEGIN
      EXECUTE IMMEDIATE v_sql
         INTO v_count;
      RETURN v_count;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000, 'Error al ejecutar consulta - ' || SQLERRM);
   END fn_execute;

   --procedimiento arma filtro
   PROCEDURE pr_arma_filtro
   (
      p_cod_consulta IN VARCHAR2,
      v_filtro       OUT LONG
   ) IS
      CURSOR filtros IS
         SELECT decode(instr(nom_referencia, '.'), 0,
                       decode(alias, NULL, NULL, alias || '.') || nom_referencia, nom_referencia) ||
                ' = ' || a.val_defecto referencia,
                a.val_defecto valor_defecto
           FROM ge_filtros b, ba_par_consultas a
          WHERE a.cod_campo = b.cod_campo
            AND a.cod_consulta = p_cod_consulta
            AND a.obligatorio = 'S';
   BEGIN
      FOR x IN filtros LOOP
         IF x.valor_defecto IS NOT NULL THEN
            IF v_filtro IS NULL THEN
               v_filtro := x.referencia;
            ELSE
               v_filtro := v_filtro || ' AND ' || x.referencia;
            END IF;
         END IF;
      END LOOP;
   
      IF v_filtro IS NULL THEN
         v_filtro := 'rownum = 1';
      ELSE
         v_filtro := v_filtro || ' AND ' || 'rownum = 1';
      END IF;
   
   END;

   --inicio
BEGIN

   FOR a IN sqls LOOP
   
      IF a.det_sql IS NOT NULL THEN
      
         --pregunto si necesita filtros
         IF instr(a.det_sql, '&P_FILTROS') > 0 THEN
            pr_arma_filtro(a.cod_consulta, v_filtro);
            IF v_filtro IS NULL THEN
               v_filtro := '1 = 1';
            END IF;
            v_plsql := REPLACE(a.det_sql, '&P_FILTROS', v_filtro);
         ELSE
            v_plsql := a.det_sql;
         END IF;
      
         --ejecuto el sql dinamico
         v_retorno := fn_execute('select count(*) from (' || v_plsql || ')');
      
      END IF;
   
      --armo mensaje
      IF v_retorno > 0 THEN
         IF v_mensaje IS NULL THEN
            v_mensaje := a.descripcion;
         ELSE
            v_mensaje := v_mensaje || chr(13) || a.descripcion;
         END IF;
      END IF;
   
   END LOOP;

   --envio mail
   IF v_mensaje IS NOT NULL THEN
   
      v_mensaje := 'Favor ejecute las sgtes. consultas dinámicas:' || chr(13) || chr(13) ||
                   v_mensaje;
   
      BEGIN
         SELECT val_parametro
           INTO v_destino
           FROM ge_par_dinamicos a
          WHERE a.parametro = 'DIR_RES_CONSULTAS';
      EXCEPTION
         WHEN OTHERS THEN
            raise_application_error(-20000,
                                    'Error al consultar parámetro DIR_RES_CONSULTAS ' || SQLERRM);
      END;
   
      it_mail.mail(v_remitente, v_destino, 'Consultas Dinámicas Plan de Cuentas', v_mensaje);
   
   END IF;

END;
/

