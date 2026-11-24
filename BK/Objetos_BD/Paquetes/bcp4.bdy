CREATE OR REPLACE PACKAGE BODY IT.bcp4 AS

   FUNCTION istext(cadena IN VARCHAR2) RETURN NUMBER IS

      i        NUMBER;
      longitud NUMBER;
      b        NUMBER;
   BEGIN

      i        := 1;
      longitud := length(cadena);
      b        := 1;
      FOR i IN 1 .. longitud LOOP
         IF NOT ((ascii(substr(cadena, i, 1)) >= 65 AND ascii(substr(cadena, i, 1)) <= 90) OR
             ascii(substr(cadena, i, 1)) = 165) THEN
            b := 0;
         END IF;
      END LOOP;
      IF b = 0 THEN
         RETURN(0);
      ELSE
         RETURN(1);
      END IF;

   END istext;

   FUNCTION isnumeric
   (
      cadena   IN VARCHAR2,
      sec_proc IN NUMBER
   ) RETURN NUMBER IS
      numero NUMBER;

   BEGIN
      SELECT to_number(cadena) INTO numero FROM dual;

      RETURN(1);

   EXCEPTION
      WHEN invalid_number THEN
         RETURN(0);
      WHEN OTHERS THEN
         mensaje('06/12', 'Error en el proceso isnumeric' || SQLERRM, sec_proc);
   END isnumeric;

   /************************************************************
   Identifica nuevos nombres y carga tablas de personas auxiliar
   *************************************************************/
   PROCEDURE new_nombres
   (
      p_cdent  IN VARCHAR2,
      periodo  IN DATE,
      sec_proc IN NUMBER
   ) IS
      -------------------------------------------------------------
      CURSOR c_pers1 IS
         SELECT a.n2 rf_tipo_ident, a.n3 rf_numero, a.n4 rf_tipo_per, a.n5 rf_apellido,
                a.n8 rf_nombre, a.n10 rf_fecha_nac, a.cdent, nvl(/*b.rf_numero*/NULL, 'X') control, a.n23,
                a.n4
           FROM t_diska a, ba_personas b
          WHERE a.cdent = p_cdent
           /* AND n2 = b.rf_tipo_ident(+)*/
           /* AND n3 = b.rf_numero(+)*/
            /*AND nvl(b.rf_numero, 'X') = 'X'*/;

      numlinea  NUMBER;
      inum      NUMBER;
      periodo1  NUMBER;
      icont     NUMBER;
      cswift    VARCHAR2(2);
      fechanac1 DATE;
      fchtest   VARCHAR2(8);
      docok     NUMBER(1); -- para verificar si el nro de doc est· bien
      codswift  NUMBER;

   BEGIN
      SELECT limerror INTO numlinea FROM parametros WHERE nminforme = 'CRC';
      inum := 0;

      --translate(nombre,  '¡ƒ¬√…ÀÕ”÷’‹⁄¥`','AAAAEEIOOOUU''''')
      --translate(apellido,'¡ƒ¬√…ÀÕ”÷’‹⁄¥`','AAAAEEIOOOUU''''')

      periodo1 := to_number(to_char(periodo, 'yyyymm'));

      FOR cn IN c_pers1 LOOP

         IF cn.rf_tipo_ident = 'CRC' THEN
            cswift := substr(cn.rf_numero, 1, 2);
         ELSE
            cswift := 'PY';
         END IF;
         /**************************************************************************************
         Verifica fechas
         ***************************************************************************************/
         IF length(cn.rf_fecha_nac) = 8 AND isnumeric(cn.rf_fecha_nac, sec_proc) > 0 THEN
            fchtest := cn.rf_fecha_nac;
         ELSE
            fchtest := NULL;
         END IF;

         IF cn.rf_tipo_ident <> 'RUC' AND fchtest IS NOT NULL THEN
            icont := isfecha(cn.rf_fecha_nac);
            IF icont = 1 THEN
               fechanac1 := to_date(substr(cn.rf_fecha_nac, 7, 2) || '/' ||
                                    substr(cn.rf_fecha_nac, 5, 2) || '/' ||
                                    substr(cn.rf_fecha_nac, 1, 4), 'DD/MM/YYYY');
            ELSE
               fechanac1 := NULL;
            END IF;
         ELSE
            fechanac1 := NULL;
         END IF;

         /**************************************************************************************
         Validar datos antes de insertar en personas_err
         ***************************************************************************************/
         docok := 0;

         /**************************************************************************************
         Para CI
         ***************************************************************************************/
         IF cn.rf_tipo_ident = 'CI' THEN
            IF cn.rf_numero = '1128314B' THEN
               docok := 0;
            END IF;
            /**************************************************************************************
            El 1er. caso es cuando toda la cadena es numerica
            ***************************************************************************************/
            IF isnumeric(substr(cn.rf_numero, length(cn.rf_numero), 1), sec_proc) = 1 THEN
               IF isnumeric(cn.rf_numero, sec_proc) = 1 AND length(cn.rf_numero) <= 7 THEN
                  IF to_number(cn.rf_numero) >= 3500 THEN
                     docok := 1;
                  ELSIF to_number(cn.rf_numero) = 581 THEN
                     docok := 1;
                  END IF;
               END IF;
            ELSE
               /**************************************************************************************
               Si la final tiene una letra
               ***************************************************************************************/
               IF isnumeric(substr(cn.rf_numero, 1, length(cn.rf_numero) - 1), sec_proc) = 1 AND
                  length(cn.rf_numero) <= 8 AND
                  istext(substr(cn.rf_numero, length(cn.rf_numero), 1)) = 1 THEN
                  IF to_number(substr(cn.rf_numero, 1, length(cn.rf_numero) - 1)) >= 3500 THEN
                     docok := 1;
                  END IF;
               END IF;
            END IF;
            /**************************************************************************************
            Para RUC
            ***************************************************************************************/
         ELSIF cn.rf_tipo_ident = 'RUC' THEN
            IF substr(cn.rf_numero, 1, 7) <> 'ESR1001' THEN
               IF length(cn.rf_numero) = 11 THEN
                  IF isnumeric(substr(cn.rf_numero, 5, 5), sec_proc) = 1 AND
                     istext(substr(cn.rf_numero, 1, 4)) = 1 AND
                     istext(substr(cn.rf_numero, 10, 2)) = 1 THEN
                     IF to_number(substr(cn.rf_numero, 7, 3)) >= 501 AND
                        to_number(substr(cn.rf_numero, 7, 3)) <= 866 THEN
                        docok := 1;
                     END IF;
                  END IF;
               END IF;
            ELSIF length(cn.rf_numero) = 10 THEN
               ----- cambio agregado el 22-03-2007 en desa4 para nuevo ruc de hacienda
               IF isnumeric(substr(cn.rf_numero, 1, 8), sec_proc) = 1 AND
                  istext(substr(cn.rf_numero, 9, 1)) = 1 AND
                  isnumeric(substr(cn.rf_numero, 10, 1), sec_proc) = 1 THEN
                  docok := 1;
               END IF;
            END IF;
         ELSIF cn.rf_tipo_ident = 'CRC' THEN

            SELECT COUNT(*) INTO codswift FROM paises WHERE cdswift = substr(cn.rf_numero, 1, 2);
            IF codswift > 0 THEN
               docok := 1;
            END IF;
         ELSIF cn.rf_tipo_ident = 'CRP' THEN
            --if IsNumeric(cn.rf_numero) = 1 then  --   ya se controla en err_formatos
            docok := 1;
            --end if;
         END IF;
         -- si el documento est· bien se inserta en errores
         IF docok = 1 THEN

            -- controlar si tiene nombre y apellido cuando se trata de una persona
            IF cn.n4 <> '001' AND (cn.rf_apellido IS NULL OR cn.rf_nombre IS NULL OR fechanac1 IS NULL) THEN
                NULL;
               /*insertar_errores(5, 'CRC', 'CA',
                                cn.rf_tipo_ident ||
                                 ' - Persona fÌsica debe tener nombre, apellido y fecha nac.',
                                cn.rf_apellido || ',' || cn.rf_nombre, '', cn.rf_numero, cn.n23,
                                p_cdent, sec_proc);*/
               -- cuando es persona jurifica solo debe tener nombre
            ELSIF cn.n4 = '001' AND cn.rf_apellido IS NOT NULL THEN
                 NULL;
               /*insertar_errores(5, 'CRC', 'CA',
                                cn.rf_tipo_ident || ' - Persona jurÌdica debe tener solo nombre',
                                cn.rf_apellido || ',' || cn.rf_nombre, '', cn.rf_numero, cn.n23,
                                p_cdent, sec_proc);*/
            ELSIF cn.rf_tipo_ident <> 'RUC' THEN
               -- cambiado else por cn.rf_tipo_ident  <> 'RUC' el 02-07-2006

               INSERT INTO personas_err x
                  (rf_tipo_ident, rf_numero, rf_pais_swift, rf_nombre, rf_apellido, rf_tipo_per,
                   rf_fecha_nac, cdent, anomes, estado, secuencia)
                  SELECT nvl(cn.rf_tipo_ident, '?'), nvl(cn.rf_numero, '?'), cswift,
                         translate(cn.rf_nombre, '¡ƒ¬√…ÀÕ”÷’‹⁄¥`', 'AAAAEEIOOOUU'''''),
                         translate(cn.rf_apellido, '¡ƒ¬√…ÀÕ”÷’‹⁄¥`', 'AAAAEEIOOOUU'''''),
                         to_number(cn.rf_tipo_per), fechanac1, cn.cdent, periodo1, '0',
                         sec_personas_err.nextval
                    FROM dual;
            END IF;
            COMMIT;
         END IF;
         --  translate(cn.rf_nombre,  '¡ƒ¬√…ÀÕ”÷’‹⁄¥`','AAAAEEIOOOUU'''''),
         -- translate(cn.rf_apellido,  '¡ƒ¬√…ÀÕ”÷’‹⁄¥`','AAAAEEIOOOUU'''''),

         inum := inum + 1;

         IF inum <= numlinea THEN
           NULL;
            /*insertar_errores(5, 'CRC', 'CA',
                             cn.rf_tipo_ident ||
                              ' - # de documento incorrecto o no registrado en PERSONAS_REF',
                             cn.rf_apellido || ',' || cn.rf_nombre, '', cn.rf_numero, cn.n23,
                             p_cdent, sec_proc);*/
         END IF;

         icont := icont + 1;
         IF icont > 100 THEN
            COMMIT;
         END IF;

      END LOOP;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(p_cdent, 'Error en el procedimiento New_nombres ' || SQLERRM, sec_proc);
   END new_nombres;

   PROCEDURE err_totales
   (
      p_cdent   IN VARCHAR2,
      numlineas IN NUMBER,
      sec_proc  IN NUMBER
   ) IS
      --------------------------------------------------------------
      montoriesgo   NUMBER;
      montocontable NUMBER;
      numlinea      NUMBER;
      riesgo1       NUMBER;
      liquidado     NUMBER;
      v_dummy       NUMBER := 1;
      v_n2          VARCHAR2(3);
      v_n3          VARCHAR2(15);

      CURSOR sumascacc IS
         SELECT a.n2, a.n3, a.n5, a.n8, a.casuma19, a.casuma20, a.ca19, a.ca20, a.cbsuma9,
                a.cbsuma10, a.n23, a.casumar
           FROM v_sumascacc a;
      --Verificar si se usara o no, con el cambio resolucion 205
      CURSOR c1 IS
         SELECT 0
           FROM t_diskc c
          WHERE c.n2 = v_n2
            AND c.n3 = v_n3
            AND c.n4 = '7800000000'
            AND c.cdent = p_cdent;

      CURSOR c2 IS
         SELECT 0
           FROM t_diskc c
          WHERE c.cdent = p_cdent
            AND c.n2 = v_n2
            AND c.n3 = v_n3
            AND c.n4 <> '7700000000'; -----modificado 02-02-2007 resolucion 205 antes  and c.n4 <> '7800000000'

      CURSOR c3 IS
         SELECT 1
           FROM t_diskb
          WHERE cdent = p_cdent
            AND n2 = v_n2
            AND n3 = v_n3
            AND n6 IN (2, 4, 5);
      CURSOR c4 IS
         SELECT 1
           FROM t_diskb
          WHERE cdent = p_cdent
            AND n4 = v_n2
            AND n5 = v_n3;

      CURSOR t_diska IS
         SELECT a.n1, a.n2, a.n3, a.n4, a.n5, a.n6, a.n7, a.n8, a.n9, a.n10, a.n11, a.n12, a.n13,
                a.n14, a.n15, a.n16, a.n17, a.n18, a.n19, a.n20, a.n21, a.n22, a.n23, a.cdent
           FROM t_diska a
          WHERE cdent = p_cdent;

   BEGIN
      montoriesgo   := 999999999999;
      montocontable := 999999999999;
      numlinea      := lineas(numlineas);

      SELECT riesgo, nvl(cdestado_oper, 0)
        INTO riesgo1, liquidado
        FROM entidades
       WHERE cdentid = p_cdent;

      /* Validar solo entidades que no esten en liquidacion o suspendidas */
      IF liquidado = 0 THEN
         -- para bancos
         IF (to_number(p_cdent) < 2000 AND length(riesgo1) < 10) OR
            (to_number(p_cdent) >= 2000 AND length(riesgo1) < 9) THEN
            NULL;
            /*insertar_errores(4, 'CRC', 'CA', 'Monto tope de riesgo incorrecto.', riesgo1, '-', '',
                             '', p_cdent, sec_proc);*/
         END IF;
         COMMIT;
      END IF;
      FOR a IN sumascacc LOOP
         v_n2 := a.n2;
         v_n3 := a.n3;
         /*******************************************************
         Verifica montos exagerados
         ********************************************************/
         IF a.casuma19 > montocontable OR a.casuma20 > montoriesgo THEN
          NULL;/* insertar_errores(4, 'CRC', 'CA',
                             a.n2 ||
                              ' - Verif. montos contable/riesgo.Montos en valor absoluto (CA)',
                             a.casuma19 || ' / ' || a.casuma20, a.cbsuma9 || ' / ' || a.cbsuma10,
                             a.n3, '', p_cdent, sec_proc);*/
         END IF;
         IF a.cbsuma9 > montocontable OR a.cbsuma10 > montoriesgo THEN
           NULL; /*insertar_errores(4, 'CRC', 'CC',
                             a.n2 ||
                              ' - Verif. montos contable/riesgo. Montos en valor absoluto (CC)',
                             a.cbsuma9 || ' / ' || a.cbsuma10, ' ', a.n3, '', p_cdent, sec_proc);*/
         END IF;
         -- Montos nulos... --C1 --deberia ser n4 <> '7700000000' por la reso 205
         /********************************************************************
         riesgo nulos en CA... modificado 02-02-2007 resolucion 205
         Antes insert into errores (iderror,modulo,fuente,mensaje,
           informado,calculado,identificador,numreg)  select 4,'CRC','CA',a.n2||
            ' - Verif. montos contable/riesgo nulos (CA)', '0','',a.n3,''  from v_sumascacc a
           where (a.casuma19 + a.casuma20) = 0  and not exists (select 0 from  diskc c  where c.n2 = a.n2
             and c.n3   = a.n3  and c.n4 = '7800000000'
         *********************************************************************/
         IF (a.casuma19 + a.casuma20) = 0 THEN
            OPEN c1;
            FETCH c1
               INTO v_dummy;
            IF c1%NOTFOUND THEN
              NULL; /*insertar_errores(4, 'CRC', 'CA',
                                a.n2 || ' - Verif. montos contable/riesgo nulos (CA)', '0', '', a.n3,
                                '', p_cdent, sec_proc);*/
            END IF;
            CLOSE c1;
         END IF;
         IF (a.cbsuma9 + a.cbsuma10) = 0 THEN
            OPEN c2; --resol 205 agregado 02-07-07
            FETCH c2
               INTO v_dummy; --resol 205 agregado 02-07-07
            IF c2%NOTFOUND THEN
               --resol 205 agregado 02-07-07
               NULL;/*insertar_errores(4, 'CRC', 'CC',
                                a.n2 || ' - Verif. montos contable/riesgo nulos (CC)', '0', '', a.n3,
                                '', p_cdent, sec_proc);*/
            END IF; --resol 205 agregado 02-07-07
            CLOSE c2; --resol 205 agregado 02-07-07
         END IF;
         /****************
         Extraido el 10-enero-2007
          where (n4 <> '7700000000' and n4 <> '7800000000')---sacar 78 ya que el n17 de diska ser· para informar contingencia
         *************/
         /*******************************************************
         Verifica totales no coincidentes
         ********************************************************/
         IF (a.casuma19 <> nvl(a.cbsuma9, -1) OR --aqui, puede ser 0 si solo tiene 78000000, y esto ya no haria falta si usamos n17 como contingencia
            a.casuma20 <> nvl(a.cbsuma10, -1)) THEN
            -- open c2;  ----ver si se sigue usando C2
            -- fetch c2 into v_dummy;
            -- if c2%found then
           NULL;/*insertar_errores(4, 'CRC', 'CA',
                             a.n2 ||
                              ' - Total contable/riesgo de CA no coincide con sumatorias contable/riesgo en CC',
                             a.casuma19 || ' / ' || a.casuma20, a.cbsuma9 || ' / ' || a.cbsuma10,
                             a.n3, '', p_cdent, sec_proc);*/
            -- end if;
            -- close c2;
         END IF;
         /********************************************************************
         Garante, cogarante o codeudor con montos de riesgo nulos en CA...
         *********************************************************************/
         IF a.casumar = 0 THEN
            OPEN c3;
            FETCH c3
               INTO v_dummy;
            IF c3%FOUND THEN
              NULL; /*insertar_errores(4, 'CRC', 'CA',
                                a.n2 ||
                                 ' - No estan registrados los montos de riesgo para persona identificada como garante/cogarante o codeudor',
                                a.casuma20, '', a.n3, a.n23, p_cdent, sec_proc);*/
            END IF;
            CLOSE c3;
         END IF;
         /********************************************************************
         Deudor con montos de riesgo nulos en CA...
         *********************************************************************/
         IF a.casuma19 = 0 THEN
            OPEN c4;
            FETCH c4
               INTO v_dummy;
            IF c4%FOUND THEN
               NULL;/*insertar_errores(4, 'CRC', 'CA',
                                a.n2 ||
                                 ' - No estan registrados los montos contables para persona identificada como deudor',
                                a.casuma19, '', a.n3, '', p_cdent, sec_proc);*/
            END IF;
            CLOSE c4;
         END IF;
      END LOOP;
      /********************************************************************
       total tc = tr, total dc = dr
      ********************************************************************/
      /*FOR a IN t_diska LOOP
         IF a.n13 <> a.n15 THEN
            insertar_errores(4, 'CRC', 'CA', a.n2 || ' - A_TOTAL_TR debe ser igual a A_TOTAL_TC',
                             a.n15, a.n13, a.n3, a.n23, p_cdent, sec_proc);
         END IF;
         IF a.n14 <> a.n16 THEN
            insertar_errores(4, 'CRC', 'CA', a.n2 || ' - A_TOTAL_DR debe ser igual a A_TOTAL_DC',
                             a.n15, a.n14, a.n3, a.n23, p_cdent, sec_proc);
         END IF;
         IF (a.n13 + a.n14) <> a.n19 THEN
            insertar_errores(4, 'CRC', 'CA', a.n2 || ' - A_TOTAL_MONTO_C incorrecto ', a.n19,
                             (a.n13 + a.n14), a.n3, a.n23, p_cdent, sec_proc);
         END IF;
         IF (a.n15 + a.n16 + a.n17 + a.n18) <> a.n20 THEN
            insertar_errores(4, 'CRC', 'CA', a.n2 || ' - A_TOTAL_MONTO_R incorrecto ', a.n20,
                             (a.n15 + a.n16 + a.n17 + a.n18), a.n3, a.n23, p_cdent, sec_proc);
         END IF;
      END LOOP;*/
      /********************************************************************
      Control del item 44000 y 45 en CC debe ser igual (a ER) +  solo con SR
      ER + solo con SR (deberia ser solo SR, si usamos el ER para contingencia
      Modificado 02-03-2007 resolucion 00205/06
      este where n4 = '4400000000' por este where n4 in ('4400000000','450000000')
      select a.n2,a.n3,(n17+n18) sumaR, b.sn10 suman10 --(n18)  from diska a,
      ********************************************************************/
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent,
          fecha_err)
         SELECT 4, 'CRC', 'CC', a.n2 || ' - Monto de codeudoria no coincide con total en CA',
                a.sumar, suman10, a.n3, '', a.cdent, SYSDATE
           FROM (SELECT a.n2, a.n3, a.n18 sumar, b.sn10 suman10, b.cdent
                    FROM t_diska a,
                         (SELECT n2, n3, SUM(n10) sn10, cdent
                             FROM t_diskc
                            WHERE cdent = p_cdent
                              AND n4 IN ('4400000000', '4500000000')
                            GROUP BY n2, n3, cdent) b
                   WHERE a.cdent = b.cdent
                     AND a.n2 = b.n2
                     AND a.n3 = b.n3) a
          WHERE a.sumar <> suman10
            AND (n2, n3) IN (SELECT n4, n5 FROM t_diskb WHERE cdent = p_cdent)
            AND rownum <= numlinea;
      COMMIT;

      /********************************************************************
      Control del item 78 en CC debe ser igual  ER de CA
      para contingencia modificado con Yolanda el 13 de noviembre del 2006
      proyecto de resolucion 205/06 agregado el 10-01-2007
      ********************************************************************/
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje,
           --modificado el 11/07/2007 errores por tabla t_errores
          --insert into t_errores (iderror,modulo,fuente,mensaje,
          informado, calculado, identificador, numreg)
         SELECT 4, 'CRC', 'CC', a.n2 || ' - Monto de contingencia no coincide con total en CA',
                a.sumar, suman10, a.n3, ''
           FROM (SELECT a.n2, a.n3, (n17) sumar, b.sn10 suman10
                    FROM t_diska a,
                         (SELECT n2, n3, SUM(n10) sn10
                             FROM t_diskc
                            WHERE n4 = '7800000000'
                            GROUP BY n2, n3) b
                   WHERE a.n2 = b.n2
                     AND a.n3 = b.n3) a
          WHERE a.sumar <> suman10
            AND rownum <= numlinea;
      COMMIT;

      /********************************************************************
      Monto contable en CC para item 44000 y 450000 debe ser cero
      Modificado el 02-04-2007 resolucion 205/06
      *********************************************************************/
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent,
          fecha_err)
         SELECT 4, 'CRC', 'CC',
                c.n2 ||
                 ' - Monto contable del item 4400000000, 4500000000 y 7800000000 debe ser cero',
                 -- agregar 4500000000
                c.n9, 0, c.n3, c.n11, cdent, SYSDATE
           FROM t_diskc c
          WHERE cdent = p_cdent
            AND n4 IN ('4400000000', '4500000000', '7800000000')
            AND --resol 205
                c.n9 <> 0
            AND rownum <= numlinea;
      COMMIT;

      /********************************************************************************************
      Monto contable = Monto riesgo en CC para item diferente de 4400000000, 4500000000, 7800000000
      Modificado el 27-07-2011 AGREGADO POR Yolanda Bejarano
      *********************************************************************************************/
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent,
          fecha_err)
         SELECT 4, 'CRC', 'CC', c.n2 || ' - Monto contable debe ser igual a Monto Riesgo', c.n9,
                c.n10, c.n3, c.n11, cdent, SYSDATE
           FROM t_diskc c
          WHERE cdent = p_cdent
            AND n4 NOT IN ('4400000000', '4500000000', '7800000000')
            AND c.n9 <> c.n10
            AND rownum <= numlinea;
      COMMIT;

      /********************************************************************
      Todos los item 44 deben estar registrados en CB
      Modificado el 02-04-2007 resolucion 205/06
      *******************************************************************/
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, informado, identificador, numreg, cdent, fecha_err)
         SELECT 4, 'CRC', 'CC',
                c.n2 ||
                 ' - Persona con item 4400000000 o item 4500000000 en CC, no registrada en CB',
                 --agregar 45
                c.n10, c.n3, c.n11, c.cdent, SYSDATE
           FROM t_diskc c, t_diskb b
          WHERE c.cdent = b.cdent
            AND c.cdent = p_cdent
            AND c.n4 IN ('4400000000', '4500000000')
            AND --resol 205
                c.n2 = b.n2(+)
            AND c.n3 = b.n3(+)
            AND nvl(b.n2, 'X') = 'X'
            AND nvl(b.n3, 'X') = 'X'
            AND rownum <= numlinea;
      COMMIT;

      --Si existen 4 archivos
      IF cantidad_archivos(p_cdent, sec_proc) = 4 THEN
         /*****************************************************************************
         Modificado el 14/12/2004
         suma del N9= monto contable correspondiente al item, siendo la actividad 701,
         debe ser igual a N15 saldo de deuda de consumo en cuentas del activo.
         suma de la actividad 701 en CC debe ser igual a saldo cuenta de CD (Deuda)
         Item 2700000000 a no sumar agregado el 07-07-2006 en Desa4 a pedido de Yolanda Bejarano y en prod7 el 02-04-2007
         Item 2800000000 a no sumar agregado el 10-01-2007 en Desa4 a pedido de resolucion 205/06 y en prod7 el 02-04-2007
         Item 4500000000 a no sumar agregado el 10-01-2007 en Desa4 a pedido de resolucion 205/06 y en prod7 el 02-04-2007
         Caso Interbanco Creditos Desafectados del Activo
         Modificado el 02-04-2007 resolucion 205/06
         antes era and n4 not in ('4400000000','7700000000','7800000000','2700000000')
         ******************************************************************************/
         INSERT INTO t_errores
            (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent,
             fecha_err)
            SELECT 4, 'CRC', 'CD', a.n2 || ' - Saldo deuda de consumo no coincide con total_c en CC',
                   a.suman15, b.suman9, a.n3, '', p_cdent, SYSDATE
              FROM (SELECT d.n2, d.n3, SUM(d.n15) suman15, cdent
                       FROM t_diskd d
                      WHERE d.cdent = p_cdent
                      GROUP BY d.n2, d.n3, cdent) a,
                   (SELECT n2, n3, SUM(n9) suman9, cdent
                       FROM t_diskc
                      WHERE cdent = p_cdent
                        AND n7 = '701'
                        AND n4 NOT IN ('4400000000', '7700000000', '7800000000', '2700000000',
                                       '2800000000', '4500000000') --modificado res 205/06 - 02-04-2007
                      GROUP BY n2, n3, cdent) b
             WHERE a.cdent = b.cdent
               AND a.n2 = b.n2
               AND a.n3 = b.n3
               AND a.suman15 <> b.suman9
               AND rownum <= numlinea;
         COMMIT;

         /*************************************************************************************************
         "Contingencia" donde (la suma del N6 = Monto Original del credito (CD)),menos (la suma del
         N15 = Saldo deuda de consumo,) sea mayor a Cero, debe ser igual al
         N10 = Monto riesgo correspondiente al item (CC), siendo item 78 y actividad 701
         CD(suma(n6)- suma(n15))  > 0 , debe ser igual a CC(N10) siendo item 78 y actividad 701
         *************************************************************************************************/
         INSERT INTO t_errores
            (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent,
             fecha_err)
            SELECT 4, 'CRC', 'CD',
                   a.n2 ||
                   --      ' - Diferencia del Credito - el Saldo deuda debe ser igual al Monto de Riesgo en CC', --cambiar error a "- Contingencia Actividad 701 (CC) diferente a saldo linea otorgada menos monto utilizado (CD)'"
                    ' - Contingencia Actividad 701 (CC) diferente a saldo linea otorgada menos monto utilizado (CD)',
                   z.sumad, a.sumac, a.n3, '', a.cdent, SYSDATE
              FROM (SELECT n2, n3, SUM(n10) sumac, cdent
                       FROM t_diskc
                      WHERE cdent = p_cdent
                        AND n7 = '701'
                        AND n4 = '7800000000'
                      GROUP BY n2, n3, cdent) a,
                   (SELECT n2, n3, SUM(n6) - SUM(n15) sumad, cdent
                       FROM t_diskd
                      WHERE cdent = p_cdent
                        AND trunc(n5, -3) IN (205000, 187000, 189000)
                      GROUP BY n2, n3, cdent
                     HAVING SUM(n6) - SUM(n15) > 0) z
             WHERE a.cdent = z.cdent
               AND a.n2 = z.n2
               AND a.n3 = z.n3
               AND a.sumac <> z.sumad
               AND rownum <= numlinea;
         COMMIT;

         /***********************************************************************************************************
         La suma del N6 = Monto Original del credito (CD)),menos (la suma del  N15 = Saldo deuda de consumo,)
         sea menor a Cero, El N10 = Monto riesgo correspondiente al item (CC), siendo item 78 y actividad 701
         debe ser igual a Cero
         CD(suma(n6)- suma(n15))  < 0   *  CC(N10) siendo item 78 y actividad 701 debe ser igual a 0
         ***********************************************************************************************************/
         INSERT INTO t_errores
            (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent,
             fecha_err)
            SELECT 4, 'CRC', 'CD', a.n2 || ' - El Monto de Riesgo en CC debe ser 0', z.sumad,
                   a.sumac, a.n3, '', a.cdent, SYSDATE
              FROM (SELECT n2, n3, SUM(n10) sumac, cdent
                       FROM t_diskc
                      WHERE cdent = p_cdent
                        AND n7 = '701'
                        AND n4 = '7800000000'
                      GROUP BY n2, n3, cdent) a,
                   (SELECT n2, n3, SUM(n6) - SUM(n15) sumad, cdent
                       FROM t_diskd
                      WHERE cdent = p_cdent
                        AND trunc(n5, -3) IN (205000, 187000, 189000)
                      GROUP BY n2, n3, cdent
                     HAVING SUM(n6) - SUM(n15) <= 0) z
             WHERE a.cdent = z.cdent
               AND a.n2 = z.n2
               AND a.n3 = z.n3
               AND a.sumac <> 0
               AND rownum <= numlinea;
      END IF;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(p_cdent, 'Error en el procedimiento Err_totales ' || SQLERRM, sec_proc);
   END err_totales;

   FUNCTION buscar_personas
   (
      pi_cdpers IN VARCHAR2,
      sec_proc  IN NUMBER
   ) RETURN BOOLEAN AS
      v_dummy NUMBER(1) := 0;
      CURSOR pers IS
         SELECT 1 FROM tipo_personas a WHERE a.cdpers = pi_cdpers;

   BEGIN
      OPEN pers;
      FETCH pers
         INTO v_dummy;
      IF pers%NOTFOUND THEN
         CLOSE pers;
         RETURN FALSE;
      ELSE
         CLOSE pers;
         RETURN TRUE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(NULL, 'Error en la funcion Buscar_personas ' || SQLERRM, sec_proc);
   END;

   FUNCTION buscar_riesgo
   (
      pi_cdriesgo IN VARCHAR2,
      sec_proc    IN NUMBER
   ) RETURN BOOLEAN AS
      v_dummy NUMBER(1) := 0;
      CURSOR riesgo IS
         SELECT 1 FROM tipo_riesgo a WHERE a.cdriesgo = pi_cdriesgo;
   BEGIN
      OPEN riesgo;
      FETCH riesgo
         INTO v_dummy;
      IF riesgo%NOTFOUND THEN
         CLOSE riesgo;
         RETURN FALSE;
      ELSE
         CLOSE riesgo;
         RETURN TRUE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(NULL, 'Error en la funcion Buscar_riesgo ' || SQLERRM, sec_proc);
   END;

   FUNCTION buscar_plazos
   (
      pi_cod_plazo IN t42_plazos.cod_plazo%TYPE,
      sec_proc     IN NUMBER
   ) RETURN BOOLEAN AS
      v_dummy NUMBER(1) := 0;
      CURSOR plazo IS
         SELECT 1 FROM t42_plazos a WHERE a.cod_plazo = pi_cod_plazo;
   BEGIN
      OPEN plazo;
      FETCH plazo
         INTO v_dummy;
      IF plazo%NOTFOUND THEN
         CLOSE plazo;
         RETURN FALSE;
      ELSE
         CLOSE plazo;
         RETURN TRUE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(NULL, 'Error en la funcion Buscar_plazo ' || SQLERRM, sec_proc);
   END;

   FUNCTION buscar_items
   (
      pi_cditem IN VARCHAR2,
      sec_proc  IN NUMBER
   ) RETURN BOOLEAN AS
      v_dummy NUMBER := 1;
      CURSOR items IS
         SELECT 1
           FROM items i
          WHERE i.cditem = pi_cditem
            AND fecha_baja IS NULL;
   BEGIN
      OPEN items;
      FETCH items
         INTO v_dummy;
      IF items%NOTFOUND THEN
         CLOSE items;
         RETURN FALSE;
      ELSE
         CLOSE items;
         RETURN TRUE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(NULL, 'Error en la funcion Buscar_items ' || SQLERRM, sec_proc);
   END;

   FUNCTION buscar_deptos
   (
      pi_cddpto IN NUMBER,
      sec_proc  IN NUMBER
   ) RETURN BOOLEAN AS
      existe  BOOLEAN;
      v_dummy NUMBER := 0;
      CURSOR deptos IS
         SELECT 1 FROM departamentos d WHERE d.cddpto = pi_cddpto;
   BEGIN
      OPEN deptos;
      FETCH deptos
         INTO v_dummy;
      IF deptos%NOTFOUND THEN
         existe := FALSE;
      ELSE
         existe := TRUE;
      END IF;
      CLOSE deptos;
      RETURN existe;

   EXCEPTION
      WHEN OTHERS THEN
         mensaje(NULL, 'Error en la funcion Buscar_deptos ' || SQLERRM, sec_proc);
   END;

   FUNCTION buscar_monedas
   (
      pi_cdmoned IN NUMBER,
      sec_proc   IN NUMBER
   ) RETURN BOOLEAN AS
      existe  BOOLEAN;
      v_dummy NUMBER := 0;
      CURSOR monedas IS
         SELECT 1
           FROM monedas m
          WHERE m.cdmoned = pi_cdmoned
            AND fecha_baja IS NULL;
   BEGIN
      OPEN monedas;
      FETCH monedas
         INTO v_dummy;
      IF monedas%NOTFOUND THEN
         existe := FALSE;
      ELSE
         existe := TRUE;
      END IF;
      CLOSE monedas;
      RETURN existe;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(NULL, 'Error en la funcion Buscar_monedas ' || SQLERRM, sec_proc);
   END;
   FUNCTION buscar_act
   (
      pi_cdact IN NUMBER,
      sec_proc IN NUMBER
   ) RETURN BOOLEAN AS
      existe  BOOLEAN;
      v_dummy NUMBER := 0;
      CURSOR act IS
         SELECT 1
           FROM actividades a
          WHERE a.cdact = pi_cdact
            AND fecha_baja IS NULL;
   BEGIN
      OPEN act;
      FETCH act
         INTO v_dummy;
      IF act%NOTFOUND THEN
         existe := FALSE;
      ELSE
         existe := TRUE;
      END IF;
      CLOSE act;
      RETURN existe;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(NULL, 'Error en la funcion Buscar_act ' || SQLERRM, sec_proc);
   END;

   PROCEDURE err_referencias
   (
      numlineas IN NUMBER,
      p_cdent   IN VARCHAR2,
      sec_proc  IN NUMBER
   ) IS
      -------------------------------------------------------------
      numlinea NUMBER;
      inum     NUMBER;
      v_dummy  NUMBER;
      CURSOR t_diska IS
         SELECT a.n1, a.n2, a.n3, a.n4, a.n5, a.n6, a.n7, a.n8, a.n9, a.n10, a.n11, a.n12, a.n13,
                a.n14, a.n15, a.n16, a.n17, a.n18, a.n19, a.n20, a.n21, a.n22, a.n23, a.cdent
           FROM t_diska a
          WHERE a.cdent = p_cdent;

      CURSOR t_diskc IS
         SELECT a.n1, a.n2, a.n3, a.n4, a.n5, a.n6, a.n7, a.n8, a.n9, a.n10, a.n11, a.cdent
           FROM t_diskc a
          WHERE a.cdent = p_cdent;
   BEGIN
      numlinea := lineas(numlineas);

      FOR a IN t_diska LOOP
         --Tipo de Personas en CA
         IF buscar_personas(a.n4, sec_proc) = FALSE THEN
                      --  insertar_errores(a.n4, '', a.n3, a.n23, p_cdent, sec_proc);
                      NULL;
         END IF;
         -- Tipo de riesgo en CA
              --     insertar_errores(3, 'CRC', 'CA', a.n2 || ' - Tipo de personas no identificado en CA',
  IF buscar_riesgo(a.n21, sec_proc) = FALSE THEN
            NULL;/*insertar_errores(3, 'CRC', 'CA', a.n2 || ' - Clasificacion de la persona incorrecta',
                             a.n21, '', a.n3, a.n23, p_cdent, sec_proc);*/
         ELSE
            -- Porcentaje correcto por tipo de riesgo en CA
            SELECT prevision INTO v_dummy FROM tipo_riesgo WHERE cdriesgo = a.n21;
            IF v_dummy <> a.n22 THEN
               NULL;/*insertar_errores(3, 'CRC', 'CA',
                                a.n2 ||
                                 ' - Porcentaje de riesgo no coincide con el riesgo informado',
                                a.n21 || '/' || a.n22, a.n21 || '/' || v_dummy, a.n3, a.n23, p_cdent,
                                sec_proc);*/
            END IF;
         END IF;

      END LOOP;

      -- Tipo de Vinculo en CB
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, informado, identificador, numreg)
         SELECT 3, 'CRC', 'CB', a.n2 || ' - CÛdigo de Vinculos no identificado', a.n6, a.n3, a.n7
           FROM t_diskb a
          WHERE a.n6 NOT IN ('02', '04', '05')
            AND a.cdent = p_cdent
            AND rownum <= numlinea;

      /*FOR c IN t_diskc LOOP
         -- Items en CC
         IF buscar_items(c.n4, sec_proc) = FALSE THEN
            NULL;\*insertar_errores(3, 'CRC', 'CC', c.n2 || ' - CÛdigo de Item no identificado', c.n4, '',
                             c.n3, c.n11, p_cdent, sec_proc);*\
         END IF;
         -- Plazos en CC
         \*IF c.n5 <> 0 THEN
           insertar_errores(3,
                            'CRC',
                            'CC',
                            c.n2 || ' - Plazos debe ser 0',
                            c.n5,
                            '',
                            c.n3,
                            c.n11,
                            p_cdent,
                            sec_proc);
         END IF;*\
         -- Resolucion 37 incluir plazos en CC
         IF buscar_plazos(c.n5, sec_proc) = FALSE THEN
            insertar_errores(3, 'CRC', 'CC', c.n2 || ' - CÛdigo de Plazo no identificado', c.n5, '',
                             c.n3, c.n11, p_cdent, sec_proc);
         END IF;

         --Regiones en CC
         IF buscar_deptos(c.n6, sec_proc) = FALSE THEN
            insertar_errores(3, 'CRC', 'CC', c.n2 || ' - CÛdigo de RegiÛn no identificado', c.n6,
                             '', c.n3, c.n11, p_cdent, sec_proc);
         END IF;
         -- Actividad en CC
         IF buscar_act(c.n7, sec_proc) = FALSE THEN
            insertar_errores(3, 'CRC', 'CC', c.n2 || ' - CÛdigo de Actividad no identificado', c.n7,
                             '', c.n3, c.n11, p_cdent, sec_proc);
         END IF;
         -- Actividad no puede ser de nivel superior
         IF c.n7 = trunc(c.n7, -2) THEN
            insertar_errores(3, 'CRC', 'CC',
                             c.n2 || ' - CÛdigo de Actividad no puede ser de nivel superior', c.n7,
                             '', c.n3, c.n11, p_cdent, sec_proc);
         END IF;
         -- Monedas en CC
         IF buscar_monedas(c.n8, sec_proc) = FALSE THEN
            insertar_errores(3, 'CRC', 'CC', c.n2 || ' - CÛdigo de Monedas no identificado', c.n8,
                             '', c.n3, c.n11, p_cdent, sec_proc);
         END IF;
      END LOOP;*/
      -- si existen 4 archivos
      IF cantidad_archivos(p_cdent, sec_proc) = 4 THEN
         -- Monedas en CD
         INSERT INTO t_errores
            (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent,
             fecha_err)
            SELECT 3, 'CRC', 'CD', a.n2 || ' - CÛdigo de Monedas no identificado', a.n8, '', a.n3,
                   a.n17, a.cdent, SYSDATE
              FROM (SELECT a.n2, a.n3, a.n8, '-1' bn6, a.n17, a.cdent
                       FROM t_diskd a, monedas b
                      WHERE a.n8 = b.cdmoned(+)
                        AND nvl(b.cdmoned, '-1') = '-1'
                        AND a.cdent = p_cdent
                        AND rownum <= numlinea) a;
      END IF;
      COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(p_cdent, 'Error en el procedimiento Err_referencias ' || SQLERRM, sec_proc);
   END err_referencias;

   PROCEDURE err_personas
   (
      numlineas IN NUMBER,
      p_cdent   IN VARCHAR2,
      periodo   IN DATE,
      sec_proc  IN NUMBER
   ) IS
      --------------------------------------------------------
      --- Rutina de calculo de errores de cedula
      --- o tipo de identidad..
      numlinea NUMBER;
      inum     NUMBER;
      limite   VARCHAR2(20);
      numbanco NUMBER;
      --periodo number;
      v_cdident VARCHAR2(3);
      v_dummy   NUMBER(1) := 0;
      d_n2      VARCHAR2(3);
      d_n3      VARCHAR2(15);
      a_n4      VARCHAR2(3);
      a_n17     NUMBER;

      CURSOR t_diska IS
         SELECT n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19,
                n20, n21, n22, n23, cdent
           FROM t_diska
          WHERE cdent = p_cdent;

      CURSOR t_diskb IS
         SELECT n1, n2, n3, n4, n5, n6, n7, cdent FROM t_diskb WHERE cdent = p_cdent;

      CURSOR t_diskc IS
         SELECT n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, cdent
           FROM t_diskc
          WHERE cdent = p_cdent;

      CURSOR t_diskd IS
         SELECT n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15, n16, n17, cdent
           FROM t_diskd
          WHERE cdent = p_cdent;

      CURSOR tipo_identidad IS
         SELECT 1 FROM tipo_identidad WHERE cdident = v_cdident;

      CURSOR tipo_pers IS
         SELECT 1, n4, n17
           FROM t_diska
          WHERE n2 = d_n2
            AND n3 = d_n3
            AND nvl(n4, '001') NOT IN ('002', '003')
            AND cdent = p_cdent;

   BEGIN
      /*Esto no debe ser asi
      select cdentid into numbanco
      from parametros
      where nminforme = 'CRC';
      ---------------------------------------------*/
      --periodo := to_number(substr(periodo,1,6));
      numlinea := lineas(numlineas);

      --(1) Borra registros viejos de personas_err
      ins_debug('err_personas', '(1) Borra registros viejos de personas_err');
      DELETE FROM personas_err
       WHERE cdent = p_cdent
         AND anomes = to_number(to_char(periodo, 'yyyymm'));
      COMMIT;
      --mensaje(numbanco,'err_personas periodo = '||to_number(to_char(periodo,'yyyymm')));
      new_nombres(p_cdent, periodo, sec_proc);

      FOR b IN t_diskb LOOP
         --exit when t_diskb%notfound;
         -- (2) Detecta personas deudoras y codeudoras al mismo tiempo
         IF b.n2 = b.n4 AND b.n3 = b.n5 THEN
           null;
            /*insertar_errores(1, 'CRC', 'CB', 'Persona registrada como Deudor = Codeudor en CB',
                             b.n2 || b.n3, '-', b.n3, b.n7, p_cdent, sec_proc);*/
         END IF;
         --Tipo de identidad del codeudor
         v_cdident := b.n2;
         OPEN tipo_identidad;
         FETCH tipo_identidad
            INTO v_dummy;
         IF tipo_identidad%NOTFOUND THEN
            ins_debug('err_personas', 'DiscoB- Tipo de identidad del codeudor');
            null;/*insertar_errores(1, 'CRC', 'CB', 'Tipo de identidad del codeudor nulo o incorrecto',
                             b.n2, '-', b.n3, b.n7, p_cdent, sec_proc);*/
         END IF;
         CLOSE tipo_identidad;
         --Tipo de identidad del deudor
         v_cdident := b.n4;
         OPEN tipo_identidad;
         FETCH tipo_identidad
            INTO v_dummy;
         IF tipo_identidad%NOTFOUND THEN
            ins_debug('err_personas', 'DiscoB- Tipo de identidad del deudor');
            /*insertar_errores(1, 'CRC', 'CB', 'Tipo de identidad del deudor nulo o incorrecto', b.n4,
                             'X', b.n3, b.n7, p_cdent, sec_proc);*/
              null;
         END IF;
         CLOSE tipo_identidad;
      END LOOP;
      FOR a IN t_diska LOOP
         EXIT WHEN t_diska%NOTFOUND;
         --(3) Tipo de persona
         IF nvl(a.n2, 'X') NOT IN ('CI', 'RUC', 'CRC', 'CRP') THEN
            /*insertar_errores(1, 'CRC', 'CA', 'Tipo de identidad nulo o incorrecto', nvl(a.n2, 'X'),
                             '-', a.n3, a.n23, p_cdent, sec_proc);*/
                             null;
         END IF;
         -- Control Swift PY para documento CRC
         IF nvl(a.n2, 'X') = 'CRC' AND substr(a.n3, 1, 2) = 'PY' THEN
            null;/*insertar_errores(1, 'CRC', 'CA', 'Para documento CRC, SWIFT no puede ser PY',
                             nvl(a.n2, 'X'), '-', a.n3, a.n23, p_cdent, sec_proc);*/
         END IF;
      END LOOP;
      FOR c IN t_diskc LOOP
         EXIT WHEN t_diskc%NOTFOUND;
         -- ins_debug('err_personas','DiscoC');
         v_cdident := c.n2;
         OPEN tipo_identidad;
         FETCH tipo_identidad
            INTO v_dummy;
         IF tipo_identidad%NOTFOUND THEN
            --Tipo de identidad nulo o incorrecto
            null;
           /* insertar_errores(1, 'CRC', 'CC', 'Tipo de identidad nulo o incorrecto', c.n2, '-', c.n3,
                             c.n11, p_cdent, sec_proc);*/

         END IF;
         CLOSE tipo_identidad;
      END LOOP;
      --si la cantidad de archivos es 4
      IF cantidad_archivos(p_cdent, sec_proc) = 4 THEN
         FOR d IN t_diskd LOOP
            EXIT WHEN t_diskd%NOTFOUND;
            d_n2 := d.n2;
            d_n3 := d.n3;
            --Nro operaciÛn Nulo
            IF TRIM(d.n4) IS NULL THEN
               ins_debug('err_personas', 'DiscoD- Nro operaciÛn Nulo');
             null;  /*insertar_errores(1, 'CRC', 'CD', 'Nro OperaciÛn nulo', d.n2, '-', d.n3, d.n4,
                                p_cdent, sec_proc);*/
            END IF;
            OPEN tipo_pers;
            FETCH tipo_pers
               INTO v_dummy, a_n4, a_n17;
            IF tipo_pers%FOUND THEN
               ins_debug('err_personas', 'DiscoD- tipo de persona no fisica');
              null; /*insertar_errores(1, 'CRC', 'CD', 'Tipo de persona no Fisica', nvl(a_n4, '001'), '-',
                                d.n3, a_n17, p_cdent, sec_proc);*/
            END IF;
            CLOSE tipo_pers;
            IF nvl(d.n2, 'X') NOT IN ('CI', 'CRP', 'CRC') THEN
               null;/*insertar_errores(1, 'CRC', 'CD',
                                'Tipo de documento debe ser CI, CRP o CRC -Persona Fisica', d.n3,
                                '-', d.n3, d.n17, p_cdent, sec_proc);*/
            END IF;
         END LOOP;
      END IF;
      -- error en nombres
      ins_debug('err_personas', 'error en nombres');
      err_nombres(p_cdent, sec_proc);
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(p_cdent, 'Error en el procedimiento Err_personas ' || SQLERRM, sec_proc);
   END err_personas;

   PROCEDURE err_nombres
   (
      p_cdent  IN VARCHAR2,
      sec_proc IN NUMBER
   ) IS
      -------------------------------------------------------
      CURSOR c_pers IS
         SELECT a.n2, a.n3, a.n4, a.n5, a.n8, a.n10, b.rf_apellido, b.rf_nombre,
                to_char(b.rf_fecha_nac, 'YYYYMMDD') rf_n10, a.n23, b.rf_fecha_baja
           FROM t_diska a, personas_ref b
          WHERE a.cdent = p_cdent
            AND a.n2 = b.rf_tipo_ident
            AND a.n3 = b.rf_numero;

      numlinea NUMBER;
      inum     NUMBER;
      inum1    NUMBER;
      icont    NUMBER;
      vnada    NUMBER(1);
      vruc_sig VARCHAR2(11);

   BEGIN
      SELECT limerror INTO numlinea FROM parametros WHERE nminforme = 'CRC';
      inum  := 0;
      inum1 := 0;
      --translate(nombre,  '¡ƒ¬√…ÀÕ”÷’‹⁄¥`','AAAAEEIOOOUU''''')
      --translate(apellido,'¡ƒ¬√…ÀÕ”÷’‹⁄¥`','AAAAEEIOOOUU''''')

      FOR cn IN c_pers LOOP
         IF inum <= numlinea THEN
            IF translate(cn.n5, '¡ƒ¬√…ÀÕ”÷’‹⁄¥`', 'AAAAEEIOOOUU''''') <>
               translate(TRIM(cn.rf_apellido), '¡ƒ¬√…ÀÕ”÷’‹⁄¥`', 'AAAAEEIOOOUU''''') OR
               translate(cn.n8, '¡ƒ¬√…ÀÕ”÷’‹⁄¥`', 'AAAAEEIOOOUU''''') <>
               translate(TRIM(cn.rf_nombre), '¡ƒ¬√…ÀÕ”÷’‹⁄¥`', 'AAAAEEIOOOUU''''') THEN
               inum := inum + 1;
               IF nvl(length(cn.n5), 0) > 0 THEN
                  /*insertar_errores(1, 'CRC', 'CA', cn.n2 || ' - Nombres o Apellidos Incorrectos',
                                   cn.n5 || ',' || cn.n8, cn.rf_apellido || ',' || cn.rf_nombre,
                                   cn.n3, cn.n23, p_cdent, sec_proc);*/
                                   NULL;
               ELSE
                  /*insertar_errores(1, 'CRC', 'CA', cn.n2 || ' - Nombres o Apellidos Incorrectos',
                                   cn.n8, cn.rf_apellido || ',' || cn.rf_nombre, cn.n3, cn.n23,
                                   p_cdent, sec_proc);*/
                                   NULL;
               END IF;
            END IF;
         END IF;

         IF inum1 <= numlinea THEN
            IF cn.n4 <> '001' AND nvl(cn.n10, '0') <> cn.rf_n10 THEN
               inum1 := inum1 + 1;
               null;
            /*insertar_errores(1, 'CRC', 'CA', cn.n2 || ' - Fecha de nacimiento Incorrectos',
                                cn.n10, cn.rf_n10, cn.n3, cn.n23, p_cdent, sec_proc);*/
            END IF;
         END IF;

         IF cn.n4 <> '001' AND (cn.n5 IS NULL OR cn.n8 IS NULL) THEN
         null;   /*insertar_errores(1, 'CRC', 'CA',
                             cn.n2 || ' - Persona fÌsica debe tener nombre y apellido',
                             cn.n5 || ',' || cn.n8, cn.rf_apellido || ',' || cn.rf_nombre, cn.n3,
                             cn.n23, p_cdent, sec_proc);*/
            /**************************************************************************************
            Cuando es persona jurifica solo debe tener nombre
            ***************************************************************************************/
         ELSIF cn.n4 = '001' AND cn.n5 IS NOT NULL THEN
           null; /*insertar_errores(5, 'CRC', 'CA', cn.n2 || ' - Persona jurÌdica debe tener solo nombre',
                             cn.n8, cn.rf_nombre, cn.n3, cn.n23, p_cdent, sec_proc);*/
         END IF;

         IF cn.n4 = '001' AND cn.n2 NOT IN ('RUC', 'CRC') THEN
           null; /*insertar_errores(5, 'CRC', 'CA',
                             cn.n2 || ' - Persona jurÌdica debe tener tipo de documento RUC o CRC',
                             cn.n2, '', cn.n3, cn.n23, p_cdent, sec_proc);*/
         END IF;

         IF cn.n4 IN ('002', '003') AND cn.n2 = 'RUC' THEN
           null; /*insertar_errores(5, 'CRC', 'CA',
                             cn.n2 || ' - Persona fÌsica no puede tener tipo de documento RUC',
                             cn.n2, '', cn.n3, cn.n23, p_cdent, sec_proc);*/
         END IF;
         /**************************************************************************************
         antes de la Ciruclar SB.SG.N∫ 00038/2006 Desafectados del activo
         ***************************************************************************************/
         /*
         if cn.n2 = 'RUC' and cn.rf_fecha_baja is not null then
           insertar_errores (5,'CRC','CA','RUC INACTIVO',
                  cn.n2,'',cn.n3,cn.n23,p_cdent,sec_proc);
         end if;*/

         /**************************************************************************************
         Ciruclar SB.SG.N∫ 00038/2006 Desafectados del activo,recibir RUC INACTIVO o cancelado,
         siempre que no cuenten con un nuevo RUC o RUC siguiente
         07-03-2006
         Item 2800000000 a no sumar agregado el 23-10-2006 a pedido de Yolanda Bejarano
         Caso Interbanco Creditos Desafectados del Activo
         Item 2800000000 a sumar segurn resolucion 2005/2006
         ***************************************************************************************/

         IF cn.n2 = 'RUC' AND cn.rf_fecha_baja IS NOT NULL THEN

            BEGIN
               vruc_sig := NULL;
               SELECT r.rucg_sig
                 INTO vruc_sig
                 FROM bco_ruc r
                WHERE r.rucg_iden = cn.n3
                  AND r.rucg_sig IS NOT NULL; -- tiene ruc sgte

            EXCEPTION
               WHEN no_data_found THEN
                  NULL;
            END;

            BEGIN
               SELECT 0
                 INTO vnada
                 FROM t_diskc c
                WHERE c.n2 = 'RUC'
                  AND c.n3 = cn.n3
                  AND c.n4 IN ('2700000000', '2800000000') --agregado caso creditos desafectados del activo Resolucion 205/2006 fecha 02-04-07
                  AND rownum < 2;
               ---
               IF vruc_sig IS NOT NULL THEN
                  -- tiene RUC sgte e item 27
                  INSERT INTO t_errores
                     (iderror, modulo, fuente, mensaje,
                       --modificado el 11/07/2007 errores por tabla t_errores
                      --insert into t_errores (iderror,modulo,fuente,mensaje,
                      informado, identificador, numreg)
                     SELECT 5, 'CRC', 'CA',
                            'RUC INACTIVO CON ITEM 27 o ITEM 28 TIENE ASIGNADO NUEVO RUC',
                             --ITEM 28 agregado 02-04-2007 resolucion 205/2006
                            cn.n2, cn.n3, cn.n23
                       FROM dual;
               END IF;

            EXCEPTION
               WHEN no_data_found THEN
                  --  no tiene item 27,o item 28 no importa estado de RUC
                  INSERT INTO t_errores
                     (iderror, modulo, fuente, mensaje,
                       --modificado el 11/07/2007 errores por tabla t_errores
                      --   insert into t_errores (iderror,modulo,fuente,mensaje,
                      informado, identificador, numreg)
                     SELECT 5, 'CRC', 'CA',
                            decode(vruc_sig, NULL, 'RUC INACTIVO',
                                    'RUC INACTIVO TIENE ASIGNADO NUEVO RUC'), cn.n2, cn.n3, cn.n23
                       FROM dual;
            END;

         END IF;
         --Si funciona bien lo de arriba borrar lo de abajo
         /*if cn.n2 = 'RUC' and cn.rf_fecha_baja is not null then

         begin
         vRuc_sig := null;
           select r.rucg_sig into vRuc_sig
           from bco_ruc r
           where r.rucg_iden = cn.n3
           and   r.rucg_sig is not null;   -- tiene ruc sgte

           insert into errores (iderror,modulo,fuente,mensaje,
              informado,identificador,numreg)
           select 5,'CRC','CA','RUC INACTIVO TIENE ASIGNADO NUEVO RUC: '||vRuc_sig,
                  cn.n2,cn.n3,cn.n23
           from dual;
         exception
           when no_data_found then
             null;
         end;
         if vRuc_sig is null then
           begin
            select 0 into vNada
            from diskc c
            where c.n2 = 'RUC'
            and   c.n3 = cn.n3
            and   c.n4 = '2700000000'; --agregar 2800000000
            ---
           exception
            when no_data_found then
              insert into errores (iderror,modulo,fuente,mensaje,
                  informado,identificador,numreg)
              select 5,'CRC','CA','Para RUC INACTIVO no fue informado Item 2700000000 en CC', ------agregar RUC INACTIVO CON ITEM 27 o ITEM 28 TIENE ASIGNADO NUEVO RUC',  --ITEM 28 agregado 02-03-2007 resolucion 205/2006
                    cn.n2,cn.n3,cn.n23
              from dual;
            end;
          end if;*/

         /**************************************************************************************
         antes de la Ciruclar SB.SG.N∫ 00038/2006 Desafectados del activo
         ***************************************************************************************/
         /*  if cn.n2 = 'RUC' and cn.rf_fecha_baja is not null then
             insert into errores (iderror,modulo,fuente,mensaje,
                  informado,identificador,numreg)
             select 5,'CRC','CA','RUC INACTIVO',
                    cn.n2,cn.n3,cn.n23
             from dual;
           end if;
         */

         /**************************************************************************************
         VALIDAR SI INFORMAN EL RUC BCPG525850I
         ***************************************************************************************/
         /* if  cn.n2 = 'RUC' AND cn.n3= 'BCPG525850I' then
          insert into errores (iderror,modulo,fuente,mensaje,
                informado,identificador,numreg)
           select 5,'CRC','CA','ESTE RUC NO DEBE SER INFORMADO',
                  cn.n2,cn.n3,cn.n23
           from dual;
         end if;*/
         /******************
         ---  ruc numerico una vez que funicone borrar el anterior
         **************/
         IF cn.n2 = 'RUC' AND cn.n3 = '80009769-6' THEN
            INSERT INTO t_errores
               (iderror, modulo, fuente, mensaje,
                 --modificado el 11/07/2007 errores por tabla t_errores
                --insert into t_errores (iderror,modulo,fuente,mensaje,
                informado, identificador, numreg)
               SELECT 5, 'CRC', 'CA', 'ESTE RUC NO DEBE SER INFORMADO', cn.n2, cn.n3, cn.n23
                 FROM dual;
         END IF;

         icont := icont + 1;
         IF icont > 100 THEN
            icont := 0;
            COMMIT;
         END IF;
      END LOOP;
      COMMIT;

   EXCEPTION
      WHEN OTHERS THEN
         mensaje(p_cdent, 'Error en el procedimiento Err_nombres ' || SQLERRM, sec_proc);
   END err_nombres;

   /**************************************************************
     Verifica relaciÛn de integridad entre CA, CB, CC y CD
   ***************************************************************/
   PROCEDURE err_integridad
   (
      numlineas IN NUMBER,
      v_cdent   IN VARCHAR2,
      sec_proc  IN NUMBER
   ) IS
      -------------------------------------------------------------
      numlinea NUMBER;
      band1    NUMBER;
      band2    NUMBER;
      CURSOR t_diska IS
         SELECT n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15, n16, n17, n18, n19,
                n20, n21, n22, n23
           FROM t_diska
          WHERE cdent = v_cdent;

      CURSOR t_diskb IS
         SELECT n1, n2, n3, n4, n5, n6, n7 FROM t_diskb WHERE cdent = v_cdent;

      CURSOR t_diskc IS
         SELECT n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11 FROM t_diskc WHERE cdent = v_cdent;

      CURSOR t_diskd IS
         SELECT n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13, n14, n15, n16, n17
           FROM t_diskd
          WHERE cdent = v_cdent;

   BEGIN
      --ins_debug('err_integridad','al inicio');
      numlinea := lineas(numlineas);
      registros_duplicados(v_cdent, sec_proc);
      --ins_debug('err_integridad','luego de registros_duplicados(v_cdent)');
      /**************************************************************************************
      Personas que est·n en CA y no en CC --Habilitado el02/07/07
      ***************************************************************************************/
      /*insert into errores (iderror,modulo,fuente,mensaje,
             informado,calculado,identificador,numreg)
        select 2,'CRC','CA',a.n2||' - Persona en CA no consta en CC',
               a.n3,'',a.n3,a.n23 from
         (select distinct a.n2,a.n3, '-1', a.n23
              from  t_diska a, t_diskc c
              where a.n2 = c.n2(+) and
                    a.n3 = c.n3(+)  and
                    nvl(c.n2,'-1') = '-1' and
                    nvl(c.n3,'-1') = '-1' and
                    rownum <= numlinea) a;
      commit;
      */
      FOR a IN t_diska LOOP
         band1 := 0;
         band2 := 0;
         /*
         for c in t_diskc loop
             if a.n2 = c.n2 and a.n3 = c.n3 then
                 band2:=1;
             end if;

         end loop; */
         SELECT COUNT(*)
           INTO band2
           FROM t_diskc c
          WHERE c.n2 = a.n2
            AND c.n3 = a.n3;

         IF band2 = 0 THEN
            -- personas que est·n en CA y no en CC
           null; /*insertar_errores(2, 'CRC', 'CA', a.n2 || ' - Persona en CA no consta en CC', a.n3, '',
                             a.n3, a.n23, v_cdent, sec_proc);*/
         END IF;
      END LOOP;
      --ins_debug('err_integridad','luego de loop1'||sysdate);
      COMMIT;

      FOR b IN t_diskb LOOP
         band1 := 0;
         band2 := 0;
         /*  for a in t_diska loop
               if b.n2=a.n2 and b.n3=a.n3 then
                  band1:=1;
              --break;
               end if;

               if b.n4 = a.n2 and b.n5 = a.n3 then
                   band2:=1;
                   --break;
               end if;
         end loop;
         */

         SELECT COUNT(*)
           INTO band1
           FROM t_diska a
          WHERE b.n2 = a.n2
            AND b.n3 = a.n3;
         IF band1 = 0 THEN
            -- (2) Personas registradas en CB (codeudor)
          null;  /*insertar_errores(2, 'CRC', 'CB', b.n2 || ' - Codeudor en CB no consta en CA', b.n3, '',
                             b.n3, b.n7, v_cdent, sec_proc);*/
         END IF;

         SELECT COUNT(*)
           INTO band2
           FROM t_diska a
          WHERE b.n4 = a.n2
            AND b.n5 = a.n3;
         IF band2 = 0 THEN
            -- (3) Personas registradas en CB (deudor)
         null;   /*insertar_errores(2, 'CRC', 'CB', b.n4 || ' - Deudor en CB no consta en CA', b.n5, '',
                             b.n5, b.n7, v_cdent, sec_proc);*/
         END IF;

         band1 := 0;
         band2 := 0;
         /*  for c in t_diskc loop
           if b.n2 = c.n2 and b.n3 = c.n3 then
             band2:=1;
             --break;
           end if;
           if b.n4 = c.n2 and b.n5 = c.n3 then
             band1:=1;
           end if;
         end loop; */

         SELECT COUNT(*)
           INTO band2
           FROM t_diskc c
          WHERE b.n2 = c.n2
            AND b.n3 = c.n3;
         IF band2 = 0 THEN
            null;/*insertar_errores(2, 'CRC', 'CB', b.n2 || ' - Codeudor en CB no consta en CC', b.n3, '',
                             b.n3, b.n7, v_cdent, sec_proc);*/
         END IF;

         SELECT COUNT(*)
           INTO band1
           FROM t_diskc c
          WHERE b.n4 = c.n2
            AND b.n5 = c.n3;
         IF band1 = 0 THEN
           null; /*insertar_errores(2, 'CRC', 'CB', b.n4 || ' - Deudor en CB no consta en CC', b.n5, '',
                             b.n5, b.n7, v_cdent, sec_proc);*/
         END IF;
      END LOOP;
      --ins_debug('err_integridad','luego de loop2'||sysdate);
      COMMIT;

      /**************************************************************************************
      Personas que est·n en CC y no en CA
      ***************************************************************************************/
      /*insert into errores (iderror,modulo,fuente,mensaje,
             informado,calculado,identificador,numreg)
        select 2,'CRC','CC',a.n2||' - Persona en CC no consta en CA',
               a.n3,'',a.n3,a.n11 from
         (select distinct c.n2,c.n3, '-1',c.n11
              from  t_diskc c, t_diska a
              where c.n2 = a.n2(+) and
                    c.n3 = a.n3(+)  and
                    nvl(a.n2,'-1') = '-1' and
                    nvl(a.n3,'-1') = '-1' and
                    rownum <= numlinea) a;
      commit;
      */
      FOR c IN t_diskc LOOP
         band1 := 0;
         /*  for a in t_diska loop
             if a.n2 = c.n2 and a.n3 = c.n3 then
                 band1:=1;
             end if;
         end loop; */
         SELECT COUNT(*)
           INTO band1
           FROM t_diska a
          WHERE c.n2 = a.n2
            AND c.n3 = a.n3;
         IF band1 = 0 THEN
            -- personas que est·n en CC y no en CA
          null;  /*insertar_errores(2, 'CRC', 'CC', c.n2 || ' - Persona en CC no consta en CA', c.n3, '',
                             c.n3, c.n11, v_cdent, sec_proc);*/
         END IF;
      END LOOP;
      --ins_debug('err_integridad','luego de loop3'||sysdate);
      COMMIT;

      -- Si existen 4 archivos
      IF cantidad_archivos(v_cdent, sec_proc) = 4 THEN
         FOR d IN t_diskd LOOP
            band1 := 0;
            band2 := 0;
            /*    for a in t_diska loop
              if d.n2 = a.n2 and d.n3 = a.n3 then
                band1:=1;
              end if;
            end loop;
            */
            SELECT COUNT(*)
              INTO band1
              FROM t_diska a
             WHERE d.n2 = a.n2
               AND d.n3 = a.n3;

            IF band1 = 0 THEN
               -- personas que est·n en CD y no en CA
              null;/* insertar_errores(2, 'CRC', 'CD', d.n2 || ' - Persona en CD no consta en CA', d.n3,
                                '', d.n3, d.n17, v_cdent, sec_proc);*/
            END IF;
            /*    for c in t_diskc loop
              if d.n2 = c.n2 and d.n3 = c.n3 then
                band2:=1;
              end if;
            end loop;
            */
            SELECT COUNT(*)
              INTO band2
              FROM t_diskc c
             WHERE d.n2 = c.n2
               AND d.n3 = c.n3;
            IF band2 = 0 THEN
               -- personas que est·n en CD y no en CC
               -- para cualquier caso o por lo menos para el item 78
             null;  /*insertar_errores(2, 'CRC', 'CD', d.n2 || ' - Persona en CD no consta en CC', d.n3,
                                '', d.n3, d.n17, v_cdent, sec_proc);*/
            END IF;
         END LOOP;
         --  ins_debug('err_integridad','luego de loop4'||sysdate);
      END IF;
      COMMIT;

   EXCEPTION
      WHEN OTHERS THEN
         mensaje(v_cdent, 'Error en el procedimiento Err_integridad ' || SQLERRM, sec_proc);
   END err_integridad;
   /*************************************************************************************/

   PROCEDURE registros_duplicados
   (
      v_cdent  IN VARCHAR2,
      sec_proc IN NUMBER
   ) IS
   BEGIN
      -- Verificar registros duplicados en CC
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, identificador, cdent, fecha_err)
         SELECT 2, 'CRC', 'CC', a.n2 || ' - ' || a.c1 || ' registros duplicados en CC', a.n3,
                a.cdent, SYSDATE
           FROM (SELECT DISTINCT t.n2, t.n3, COUNT(*) c1, t.cdent
                    FROM t_diskc t
                   WHERE cdent = v_cdent
                   GROUP BY t.n2, t.n3, t.n4, t.n5, t.n6, t.n7, t.n8, cdent
                  HAVING COUNT(*) > 1) a;
      -- Verificar registros duplicados en CB
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, identificador, cdent, fecha_err)
         SELECT 2, 'CRC', 'CC',
                ' - Registro duplicado (' || a.c1 || ') en CB: ' || a.n2 || a.n3 || '-' || a.n4 || a.n5,
                a.n3, a.cdent, SYSDATE
           FROM (SELECT DISTINCT n2, n3, n4, n5, n6, COUNT(*) c1, cdent
                    FROM t_diskb t
                   WHERE cdent = v_cdent
                   GROUP BY n2, n3, n4, n5, n6, cdent
                  HAVING COUNT(*) > 1) a;
      -- registros duplicados en CA
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, identificador, cdent, fecha_err)
         SELECT 2, 'CRC', 'CA', a.n2 || ' - ' || a.c1 || ' registros duplicados en CA', a.n3,
                a.cdent, SYSDATE
           FROM (SELECT DISTINCT t.n2, t.n3, COUNT(*) c1, cdent
                    FROM t_diska t
                   WHERE cdent = v_cdent
                   GROUP BY t.n2, t.n3, cdent
                  HAVING COUNT(*) > 1) a;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(v_cdent, 'Error en el procedimiento Registros_duplicados ' || SQLERRM, sec_proc);
   END registros_duplicados;
   ----------------------------------------------------------------------
   PROCEDURE err_discod
   (
      numlineas IN NUMBER,
      cdent     IN VARCHAR2,
      periodo   IN DATE,
      sec_proc  IN NUMBER
   ) IS
      CURSOR dd IS
         SELECT * FROM t_diskd d WHERE d.cdent = cdent;

      v_anomes  NUMBER(8);
      v_nrodias NUMBER(8);
      numlinea  NUMBER;
   BEGIN
      --mensaje(cdent,'err_discod periodo = '||periodo);
      SELECT limerror INTO numlinea FROM parametros WHERE nminforme = 'CRC';

      -- recupera periodo
      /* select to_char(last_day(to_date(to_char(anomes),'yyyymm')),'yyyymmdd')
      into v_anomes
      from parametros
      where nminforme = 'CRC';*/
      v_anomes := to_char(last_day(to_date(to_char(periodo, 'yyyymm'), 'yyyymm')), 'yyyymmdd');
      -- Numero de operacion duplicado
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent)
         SELECT 4, 'CRC', 'CD', a.n2 || ' - Nro.Operacion duplicado, tipo: ' || a.n5, a.n4, '', a.n3,
                a.n17, cdent
           FROM t_diskd a,
                (SELECT d.n5, d.n4, d.n8
                    FROM t_diskd d
                   GROUP BY d.n5, d.n4, d.n8, d.n2, d.n3
                  HAVING COUNT(*) > 1) b
          WHERE a.n4 = b.n4
            AND a.n5 = b.n5
            AND a.n8 = b.n8
            AND rownum <= numlinea;
      COMMIT;

      -- Numero de titulares por operacion
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent)
         SELECT a.*
           FROM (SELECT 4, 'CRC', 'CD',
                         to_char(COUNT(*)) || ' Titulares para la operacion, Tipo: ' || d.n5 ||
                          ' Moneda: ' || to_char(d.n8), d.n4, '' x1, '' x2, 0, cdent
                    FROM t_diskd d
                   GROUP BY d.n5, d.n4, d.n8, cdent
                  HAVING COUNT(*) > 10) a
          WHERE rownum <= numlinea;

      COMMIT;

      -- Montos o fechas diferentes para los titulares de la misma operacion
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent,
          fecha_err)
      --select a.* from
         SELECT 4, 'CRC', 'CD',
                'Montos o fechas diferentes para los titulares de la operacion, Tipo: ' || d.n5 ||
                 ' Moneda: ' || to_char(d.n8), d.n4, '' x1, '' x2, 0, cdent, SYSDATE
           FROM t_diskd d
          WHERE rownum <= numlinea
          GROUP BY d.n5, d.n4, d.n8, cdent
         HAVING MAX(d.n6) <> MIN(d.n6) -- monto original del credito
         OR MAX(d.n7) <> MIN(d.n7) -- fecha operacion
         OR MAX(d.n8) <> MIN(d.n8) -- moneda
         OR MAX(d.n9) <> MIN(d.n9) -- tasa de interes
         OR MAX(d.n10) <> MIN(d.n10) -- fcha 1er vencimiento
         OR MAX(d.n11) <> MIN(d.n11) -- fcha venc prxima cuota impaga
         OR MAX(d.n12) <> MIN(d.n12) -- fcha ult vencimiento
         OR MAX(d.n13) <> MIN(d.n13) -- dias atraso
         OR MAX(d.n14) <> MIN(d.n14) -- nro cuotas canceladas
         OR MAX(d.n15) <> MIN(d.n15) -- saldo ca
         OR MAX(d.n16) <> MIN(d.n16) -- monto cuotas atrasadas
         ;

      COMMIT;

      -- Codigos definidos en la Res.230-D3
      INSERT INTO t_errores
         (iderror, modulo, fuente, mensaje, informado, calculado, identificador, numreg, cdent)
         SELECT 4, 'CRC', 'CD',
                d.n2 || ' - Tipo de Operacion no corresponde a Res.230-D3: ' || to_char(d.n5), d.n4,
                '', d.n3, d.n17, cdent
           FROM t_diskd d
          WHERE NOT EXISTS (SELECT 0
                   FROM cr_tipo_operacion t
                  WHERE t.tipo_ope = d.n5
                    AND t.fecha_baja IS NULL);
      COMMIT;
      --
      FOR r IN dd LOOP

         --if trunc(r.n5,-3) not in (169000,173000,187000,189000,205000,351000,405000) then
         --  insert into errores (iderror,modulo,fuente,mensaje,
         --       informado,calculado,identificador,numreg)
         --   values(4,'CRC','CD',r.n2||' - Tipo de Operacion no corresponde a Res.230-D3',
         --       r.n5,'',r.n3,r.n17);
         --end if;
         --
         IF r.n7 = 0 OR r.n7 > v_anomes THEN
           null;/* insertar_errores(4, 'CRC', 'CD',
                             r.n2 || ' - Fecha de Operacion nula o Posterior al informe, tipo: ' || r.n5,
                             r.n7, v_anomes, r.n3, r.n17, r.cdent, sec_proc);*/
         END IF;
         --
         IF r.n10 = 0 THEN
            IF trunc(r.n5, -3) NOT IN (187000, 189000, 205000) THEN
            null;/*   insertar_errores(4, 'CRC', 'CD',
                                r.n2 || ' - Fecha 1er. Vencimiento Vacio, tipo: ' || r.n5, r.n10, '',
                                r.n3, r.n17, r.cdent, sec_proc);*/
            END IF;
         ELSE
            IF r.n10 < r.n7 THEN
             null;  /*insertar_errores(4, 'CRC', 'CD',
                                r.n2 || ' - Fecha 1er.Vto.Anterior a la fecha de operacion, tipo: ' || r.n5,
                                r.n10, r.n7, r.n3, r.n17, r.cdent, sec_proc);*/
            END IF;
         END IF;
         --
         IF r.n11 = 0 THEN
           null; /*insertar_errores(4, 'CRC', 'CD',
                             r.n2 || ' - Fecha de Venc.siguiente cuota impaga es Cero, tipo:' || r.n5,
                             r.n10, '', r.n3, r.n17, r.cdent, sec_proc);*/
         ELSE
            IF r.n10 > r.n11 THEN
               null;/*insertar_errores(4, 'CRC', 'CD',
                                r.n2 ||
                                 ' - Fecha.Venc.siguiente cuota impaga menor a 1er.Venc., tipo:' || r.n5,
                                r.n11, r.n10, r.n3, r.n17, r.cdent, sec_proc);*/
            END IF;
         END IF;
         --
         IF r.n12 = 0 THEN
            IF trunc(r.n5, -3) NOT IN (187000, 189000, 205000) THEN
              null; /*insertar_errores(4, 'CRC', 'CD',
                                r.n2 || ' - Fecha de Ult.Vencimiento es Cero, tipo:' || r.n5, r.n12,
                                '', r.n3, r.n17, r.cdent, sec_proc);*/
            END IF;
         ELSE
            IF r.n12 < r.n10 THEN
            null; /* insertar_errores(4, 'CRC', 'CD',
                                r.n2 ||
                                 ' - Fecha de Ult.Vencimiento menor a 1er.Vencimiento, tipo:' || r.n5,
                                r.n12, r.n10, r.n3, r.n17, r.cdent, sec_proc);*/
            END IF;
         END IF;
         -- Dias de atraso: (fch.informe - fch.sgte.cuota.impaga)
         v_nrodias := to_date(to_char(v_anomes), 'yyyymmdd') - to_date(to_char(r.n11), 'yyyymmdd');
         IF v_nrodias < 0 THEN
            v_nrodias := 0;
         END IF;
         IF v_nrodias <> r.n13 THEN
            null;/*insertar_errores(4, 'CRC', 'CD',
                             r.n2 || ' - Nro.dias de atraso incorrecto, tipo:' || r.n5, r.n13,
                             v_nrodias, r.n3, r.n17, r.cdent, sec_proc);*/
         END IF;
         --
         IF r.n14 <> 0 THEN
            IF trunc(r.n5, -3) IN (187000, 189000, 205000) THEN
              null; /*insertar_errores(4, 'CRC', 'CD',
                                r.n2 || ' - Numero de cuotas canceladas debe ser cero, tipo:' || r.n5,
                                r.n14, '', r.n3, r.n17, r.cdent, sec_proc);*/
            END IF;
         END IF;
         --
         IF r.n17 = 0 THEN
           null; /*insertar_errores(4, 'CRC', 'CD', r.n2 || ' - Numero de registro es cero', r.n17, '',
                             r.n3, r.n17, r.cdent, sec_proc);*/
         END IF;

         --
         --  DÌas de atraso mayor a cero y monto cuotas atrasadas igual a cero   ----11/11/2003
         IF r.n13 > 0 AND r.n16 = 0 THEN
            null;/*insertar_errores(4, 'CRC', 'CD',
                             r.n2 ||
                              ' - Con dÌas de atraso > 0, Monto cuotas atrasadas no puede ser 0, tipo:' || r.n5,
                             r.n13, '', r.n3, r.n17, r.cdent, sec_proc);*/
         END IF;

         --  Saldo deuda de consumo igual a cero y monto cuotas atrasadas mayor a cero ----11/11/2003
         IF r.n15 = 0 AND r.n16 > 0 THEN
            null;/*insertar_errores(4, 'CRC', 'CD',
                             r.n2 ||
                              ' - Con Saldo = 0, Monto cuotas atrasadas no puede ser mayor a 0, tipo:' || r.n5,
                             r.n16, '', r.n3, r.n17, r.cdent, sec_proc);*/
         END IF;

         --  DÌas de atraso igual a cero y monto cuotas atrasadas igual a cero  ----11/11/2003
         IF r.n13 = 0 AND r.n16 > 0 THEN
            IF trunc(r.n5, -3) NOT IN (187000, 189000) THEN
               null;/*insertar_errores(4, 'CRC', 'CD',
                                r.n2 ||
                                 ' - Con dÌas de atraso = 0, Monto cuotas atrasadas no puede ser mayor a 0, tipo:' || r.n5,
                                r.n9, '', r.n3, r.n17, r.cdent, sec_proc);*/
            END IF;
         END IF;

         --  Tasa de interes igual a cero  ----13/11/2003
         IF r.n9 = 0 THEN
          null; /* insertar_errores(4, 'CRC', 'CD',
                             r.n2 || ' - Tasa de interes no puede ser 0, tipo:' || r.n5, r.n16, '',
                             r.n3, r.n17, r.cdent, sec_proc);*/
         END IF;
         --

      END LOOP;
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(cdent, 'Error en el procedimiento Err_discod ' || SQLERRM, sec_proc);
   END err_discod;

   -------------------------------------------------------
   FUNCTION isfecha(cadena IN VARCHAR2) RETURN NUMBER IS
      -------------------------------------------------------
      numero NUMBER;
      fecha  DATE;
   BEGIN
      numero := 0;
      SELECT to_date(cadena, 'yyyymmdd') INTO fecha FROM dual;
      IF to_date(cadena, 'yyyymmdd') > to_date('16990101', 'yyyymmdd') OR cadena IS NULL THEN
         numero := 1;
      END IF;
      RETURN(numero);

   EXCEPTION
      WHEN OTHERS THEN
         RETURN(numero);
   END isfecha;

   /*******************************************************
      Trunca la tabla errores
   *******************************************************/
   /*PROCEDURE truncar_errores IS
   BEGIN
     EXECUTE IMMEDIATE 'truncate table errores'; --revisar si se trunca esta o t_errores
   END truncar_errores;*/
   /*******************************************************
        Inserta lugar, sysdate para detectar donde es lento
   *******************************************************/
   PROCEDURE ins_debug
   (
      p_lugar   IN VARCHAR2,
      p_mensaje IN VARCHAR2
   ) IS
   BEGIN
      INSERT INTO rob_debug(MODULO,Fecha,lugar,mensaje,programa) VALUES ('CRC', SYSDATE, p_lugar, substr(p_mensaje, 1, 200),NULL);
   END;
   /****************************************************************
    # de errores por tipo de error en funciÛn de la tabla par·metros
   *****************************************************************/
   FUNCTION lineas(numlineas NUMBER) RETURN NUMBER AS
      ------------------------------------------------------------------
      numlinea NUMBER;
      numerror NUMBER;

   BEGIN
      IF numlineas IS NULL THEN
         numlinea := 100;
      END IF;

      IF numlineas = 0 OR numlineas > 9999 THEN
         numlinea := 9999;
      ELSE
         numlinea := numlineas;
      END IF;

      RETURN numlinea;
   END lineas;

   /****************************************************************
      Obtiene el periodo de datos en base a la tabla PARAMETROS
   *****************************************************************/
   FUNCTION f_periodo RETURN VARCHAR2 AS
      -----------------------------------------------------------------
      per1     VARCHAR2(8);
      v_anomes parametros.anomes%TYPE;

   BEGIN
      SELECT anomes INTO v_anomes FROM parametros WHERE nminforme = 'CRC';

      SELECT to_char(last_day(to_date(v_anomes || '01', 'yyyymmdd')), 'YYYYMMDD')
        INTO per1
        FROM dual;

      RETURN per1;
   END f_periodo;

   /****************************************************
   --Procedimiento para auditar operaciones
   -- Inicializa tambien variable global fechaini de
   -- medicion de tiempos
   *****************************************************/
   PROCEDURE mensaje
   (
      p_numbanco IN VARCHAR2,
      mens1      IN VARCHAR2,
      sec_proc   IN NUMBER
   ) IS
      ------------------------------------------------------
      banco    VARCHAR2(4);
      periodo1 NUMBER;
      tiempo   NUMBER;
      mensok   VARCHAR2(255);

   BEGIN
      IF mens1 IS NULL THEN
         RETURN;
      END IF;

      IF fechaini IS NOT NULL THEN
         SELECT round((SYSDATE - fechaini) * 24 * 60, 2) INTO tiempo FROM dual;
      ELSE
         fechaini := SYSDATE;
         tiempo   := 0;
      END IF;

      periodo1 := substr(f_periodo, 1, 6);
      mensok   := TRIM(mens1) || ' (' || tiempo || ' min.)';

      /*select cdentid into numbanco
      from parametros
      where nminforme = 'CRC';*/
      IF p_numbanco IS NULL THEN
         SELECT DISTINCT cdent INTO banco FROM t_diska;
      ELSE
         banco := p_numbanco;
      END IF;
      INSERT INTO auditlog
         (modulo, cdent, anomes, hora, mensaje, sec_proc)
         SELECT 'CRC', banco, periodo1, SYSDATE, mensok, sec_proc FROM dual;
      COMMIT;

      fechaini := SYSDATE;
   EXCEPTION
      WHEN OTHERS THEN
         ins_debug('mensaje', 'mensaje ' || SQLERRM);
   END mensaje;

   /**************************************************
        Inicializar periodo nuevo
   **************************************************/

   PROCEDURE initperiodo(p_anomes IN NUMBER) IS

      v_anomes NUMBER; -- aÒo mes anterior
   BEGIN

      SELECT anomes INTO v_anomes FROM parametros WHERE nminforme = 'CRC';

      /*****************************************************/
      DELETE FROM entidades_his h
       WHERE h.modulo = 'CRC'
         AND h.periodo = v_anomes;
      COMMIT;
    /*  INSERT INTO entidades_his
         SELECT e.cdentid, e.nmentid, e.pathroot, e.estado, e.cdestado_oper, e.reg_ca, e.reg_cb,
                e.reg_cc, e.fechainf, v_anomes, 'CRC'
           FROM entidades e;*/
      COMMIT;
      /******************************************************/

      UPDATE entidades a
         SET a.estado   = 0,
             a.pathroot = NULL,
             a.fechainf = NULL,
             a.riesgo   = 0,
             a.reg_ca   = 0,
             a.reg_cb   = 0,
             a.reg_cc   = 0;
      -- poner un where para los que fueron aprobados con restricciÛn
      COMMIT;

      UPDATE parametros
         SET anomes  = p_anomes,
             cdentid = '0'
       WHERE nminforme = 'CRC';
      COMMIT;
      -- limpiar tablas
      --execute immediate 'truncate table AUDITLOG';
      /*delete from diska;
      commit;
      delete from diskb;
      commit;
      delete from diskc;
      commit;
      delete from diskd;
      commit;*/

   END initperiodo;

   FUNCTION cantidad_archivos
   (
      cdent    IN VARCHAR2,
      sec_proc IN NUMBER
   ) RETURN NUMBER AS
      cantidad NUMBER;
      CURSOR c1 IS
         SELECT COUNT(archivo)
           FROM archivos_informados
          WHERE cdentid = cdent
            AND modulo = 'CRC'
            AND fecha_desde < SYSDATE
            AND (fecha_baja >= SYSDATE OR fecha_baja IS NULL);

   BEGIN
      OPEN c1;
      FETCH c1
         INTO cantidad;
      CLOSE c1;
      RETURN cantidad;
   EXCEPTION
      WHEN no_data_found THEN
         mensaje(cdent, 'No se encontrÛ la cantidad de archivos de la entidad', sec_proc);
   END;

   --resolucion5/2010 calificacion 2a, 2b
   PROCEDURE montatablas
   (
      numbanco VARCHAR2,
      sec_proc IN NUMBER
   ) IS
      CURSOR ca_cur IS
         SELECT /*+ full(a) parallel(a,4) */
          substr(texto, 1, 2) n1, TRIM(substr(texto, 3, 3)) n2,
          ltrim(rtrim(substr(texto, 6, 15)), '0') n3, substr(texto, 21, 3) n4,
          TRIM(substr(texto, 24, 30)) n5, substr(texto, 54, 15) n6, substr(texto, 69, 15) n7,
          TRIM(substr(texto, 84, 60)) n8, substr(texto, 144, 15) n9,
          TRIM(ltrim(substr(texto, 159, 15), '0')) n10, to_number(substr(texto, 174, 3)) n11,
          to_number(substr(texto, 177, 15)) n12, to_number(substr(texto, 192, 15)) n13,
          to_number(substr(texto, 207, 15)) n14, to_number(substr(texto, 222, 15)) n15,
          to_number(substr(texto, 237, 15)) n16, to_number(substr(texto, 252, 15)) n17,
          to_number(substr(texto, 267, 15)) n18, to_number(substr(texto, 282, 15)) n19,
          to_number(substr(texto, 297, 15)) n20,
          --substr(texto, 312, 1) n21,
          TRIM(substr(texto, 312, 2)) n21,
          --to_number(substr(texto, 313, 6)) / 100 n22,
          to_number(substr(texto, 314, 6)) / 100 n22, numreg n23, numbanco, texto
           FROM archivos a
          WHERE cdent = numbanco
            AND archivo = 'CA'; --and
      --substr(texto,1,2) = '06';

      CURSOR cb_cur IS
         SELECT /*+ full(a) parallel(a,4) */
          substr(rtrim(texto), 1, 2) n1, TRIM(substr(rtrim(texto), 3, 3)) n2,
          ltrim(rtrim(substr(texto, 6, 15)), '0') n3, TRIM(substr(rtrim(texto), 21, 3)) n4,
          ltrim(rtrim(substr(texto, 24, 15)), '0') n5, substr(rtrim(texto), 39, 2) n6, numreg n7,
          numbanco
           FROM archivos a
          WHERE cdent = numbanco
            AND archivo = 'CB'
            AND substr(texto, 1, 2) = '07';

      CURSOR cc_cur IS
         SELECT /*+ full(a) parallel(a,4) */
          substr(texto, 1, 2) n1, TRIM(substr(texto, 3, 3)) n2,
          ltrim(rtrim(substr(texto, 6, 15)), '0') n3, to_number(substr(texto, 21, 10)) n4,
          to_number(substr(texto, 31, 2)) n5, to_number(substr(texto, 33, 3)) n6,
          to_number(substr(texto, 36, 3)) n7, to_number(substr(texto, 39, 4)) n8,
          to_number(substr(texto, 43, 15)) n9, to_number(substr(texto, 58, 15)) n10, numreg n11,
          numbanco
           FROM archivos a
          WHERE cdent = numbanco
            AND archivo = 'CC'
            AND substr(texto, 1, 2) = '08';

      CURSOR cd_cur IS
         SELECT /*+ full(a) parallel(a,4) */
          substr(texto, 1, 2) n1, TRIM(substr(texto, 3, 3)) n2,
          ltrim(rtrim(substr(texto, 6, 15)), '0') n3, TRIM(substr(texto, 21, 20)) n4,
          to_number(substr(texto, 41, 6)) n5, to_number(substr(texto, 47, 17)) / 100 n6,
                     to_number(trim(substr(texto, 64, 8))) n7,
          --to_number(substr(texto, 64, 8)) n7,
          to_number(substr(texto, 72, 4)) n8,
          to_number(substr(texto, 76, 5)) / 100 n9, to_number(substr(texto, 81, 8)) n10,
          to_number(substr(texto, 89, 8)) n11, to_number(substr(texto, 97, 8)) n12,
          to_number(substr(texto, 105, 4)) n13, to_number(substr(texto, 109, 3)) n14,
          to_number(substr(texto, 112, 17)) / 100 n15, to_number(substr(texto, 129, 17)) / 100 n16,
          numreg n17, numbanco
           FROM archivos a
          WHERE cdent = numbanco
            AND archivo = 'CD'
            AND substr(texto, 1, 2) = '10';

      inum           NUMBER;
      v_disk         VARCHAR2(2);
      v_count_commit NUMBER(5) := 0;
      riesgo1        NUMBER;
      conta          NUMBER := 0;
      contb          NUMBER := 0;
      contc          NUMBER := 0;
      /*******************************************************
       Verificar la existencia de registros
      *******************************************************/
   BEGIN
      fechaini := SYSDATE;
      --mensaje (numbanco,'Monta archivos: Inicio... ',sec_proc);
      SELECT /*+ full(a) parallel(a,4) */
       COUNT(*)
        INTO inum
        FROM archivos a
       WHERE cdent = numbanco
         AND archivo IN ('CA', 'CB', 'CC', 'CD');

      /*******************************************************
       Si no hay registros..abandonar...
      *******************************************************/
      IF inum = 0 THEN
         RETURN;
      END IF;

      EXECUTE IMMEDIATE 'truncate table t_diska';
      EXECUTE IMMEDIATE 'truncate table t_diskb';
      EXECUTE IMMEDIATE 'truncate table t_diskc';
      EXECUTE IMMEDIATE 'truncate table t_diskd';
      EXECUTE IMMEDIATE 'truncate table t_errores';
      --mensaje (numbanco,'Monta archivos: tablas inicializadas',sec_proc);

      --update parametros set cdentid = numbanco where nminforme = 'CRC';

      /*******************************************************
      Cargar DISKA
      ********************************************************/
      --mensaje (numbanco,'Monta archivos: PERSONAS (CA)... ', sec_proc);
      v_disk         := 'CA';
      v_count_commit := 0;
      FOR r IN ca_cur LOOP
         v_count_commit := v_count_commit + 1;
         IF r.n1 = '06' THEN
            INSERT INTO t_diska
            VALUES
               (r.n1, r.n2, r.n3, r.n4, r.n5, r.n6, r.n7, r.n8, r.n9, r.n10, r.n11, r.n12, r.n13,
                r.n14, r.n15, r.n16, r.n17, r.n18, r.n19, r.n20, r.n21, r.n22, r.n23, r.numbanco);
            IF v_count_commit >= 100 THEN
               v_count_commit := 0;
               COMMIT;
            END IF;
            conta := conta + 1;
         ELSE
            riesgo1 := to_number(substr(r.texto, 27, 15));
         END IF;

      END LOOP;
      COMMIT;

      --mensaje (numbanco,'Monta archivos: VINCULOS (CB)... ',sec_proc);
      v_disk         := 'CB';
      v_count_commit := 0;

      /*******************************************************
      Cargar DISKB
      ********************************************************/
      FOR r IN cb_cur LOOP
         v_count_commit := v_count_commit + 1;
         INSERT INTO t_diskb(N1,N2,N3,N4,N5,N6,N7,Numbanco) VALUES (r.n1, r.n2, r.n3, r.n4, r.n5, r.n6, r.n7, r.numbanco);
         IF v_count_commit >= 100 THEN
            v_count_commit := 0;
            COMMIT;
         END IF;
         contb := contb + 1;
      END LOOP;
      COMMIT;

      /*******************************************************
      Cargar DISKC
      ********************************************************/
      --mensaje (numbanco,'Monta archivos: ITEMS (CC)... ',sec_proc);
      v_disk         := 'CC';
      v_count_commit := 0;
      FOR r IN cc_cur LOOP
         v_count_commit := v_count_commit + 1;
         INSERT INTO t_diskc(N1,N2,N3,N4,N5,N6,N7,N8,N9,N10,N11,numbanco)
         VALUES
            (r.n1, r.n2, r.n3, r.n4, r.n5, r.n6, r.n7, r.n8, r.n9, r.n10, r.n11, r.numbanco);
         IF v_count_commit >= 100 THEN
            v_count_commit := 0;
            COMMIT;
         END IF;
         contc := contc + 1;
      END LOOP;
      COMMIT;
      -- IF cantidad_archivos(numbanco, sec_proc) = 4 THEN
      /*******************************************************
      Cargar DISKD
      ********************************************************/
      --mensaje (numbanco,'Monta archivos: ITEMS (CD)... ',sec_proc);
      v_disk         := 'CD';
      v_count_commit := 0;
      FOR r IN cd_cur LOOP
         v_count_commit := v_count_commit + 1;
         INSERT INTO t_diskd(N1,N2,N3,N4,N5,N6,N7,N8,N9,N10,N11,N12,N13,N14,N15,N16,N17,numbanco)
         VALUES
            (r.n1, r.n2, r.n3, r.n4, r.n5, r.n6, r.n7, r.n8, r.n9, r.n10, r.n11, r.n12, r.n13,
             r.n14, r.n15, r.n16, r.n17, r.numbanco);
         IF v_count_commit >= 100 THEN
            v_count_commit := 0;
            COMMIT;
         END IF;

      END LOOP;
      COMMIT;

      --se inicializa entidades
      UPDATE entidades
         SET reg_ca   = conta,
             reg_cb   = contb,
             reg_cc   = contc,
             riesgo   = riesgo1,
             fechainf = SYSDATE,
             orden    = NULL
       WHERE cdentid = numbanco;

   EXCEPTION
      WHEN invalid_number THEN
         INSERT INTO t_errores
            (iderror, modulo, fuente, mensaje) --modificado el 11/07/2007 errores por tabla t_errores
         --insert into t_errores (iderror,modulo,fuente,mensaje)
            SELECT 0, 'CRC', v_disk, 'Error de Formato: Montos numericos invalidos' FROM dual;
         COMMIT;
         RETURN;

   END montatablas;

   /************************************************************
            Rutina principal de validaciÛn
   *************************************************************/
   PROCEDURE validacion
   (
      numbanco  VARCHAR2,
      numlineas NUMBER,
      periodo   DATE,
      sec_proc  NUMBER
   ) IS
      -------------------------------------------------------------
      -- numbanco = codigo de entidad
      -- numlineas = cantidad m·xima de cada tipo de error

      inum     NUMBER;
      inuma    NUMBER;
      inumb    NUMBER;
      inumc    NUMBER;
      numb1    NUMBER;
      numb2    NUMBER;
      numlinea NUMBER;
      cde      VARCHAR2(4);
      fechain  DATE;

   BEGIN
      fechaini := SYSDATE;
      fechain  := SYSDATE;

      --mensaje(numbanco,'validacion periodo = '||to_char(periodo,'yyyymm'));
      DELETE FROM rob_debug WHERE programa = 'CRC';
      COMMIT;

      IF numbanco IS NULL THEN
         RETURN;
      END IF;
      numb1 := to_number(numbanco);

      --delete from auditlog where cdent = numbanco and anomes = substr(f_periodo,1,6);
      --commit;
      DELETE FROM t_errores;
      dbms_application_info.set_module('BCP4', 'inicio');

      /**********************************************************************************************
      Montar tablas para continuar validaciÛn
      **********************************************************************************************/
      ins_debug('montatablas', 'inicio');
      montatablas(numbanco, 0);
      ins_debug('montatablas', 'fin');

      -----------------------------------------------------------------------
      --  leer_raw(numbanco);-- procedimiento auxiliar para carga archivos a las tablas t_disk%
      ------------------------------------------------------------------------
      ins_debug('err_personas', '');
      dbms_application_info.set_action('err_personas');
      err_personas(numlineas, numbanco, periodo, sec_proc);

      --  mensaje(numbanco,'ValidaciÛn: Personas existentes o validas ',sec_proc);
      -- IDERROR = 2
      ins_debug('err_integridad', '');
      dbms_application_info.set_action('err_integridad');
      err_integridad(numlineas, numbanco, sec_proc);
      --  mensaje(numbanco,'ValidaciÛn: Integridad referencial ',sec_proc);
      -- IDERROR = 3
      ins_debug('err_referencias', '');
      dbms_application_info.set_action('err_referencias');
      err_referencias(numlineas, numbanco, sec_proc);
      --  mensaje(numbanco,'ValidaciÛn: Referencias con tablas auxiliares ',sec_proc);
      -- IDERROR = 4
      ins_debug('err_totales', '');
      dbms_application_info.set_action('err_totales');
      err_totales(numbanco, numlineas, sec_proc);
      --  mensaje(numbanco,'ValidaciÛn: Verificar montos totales ',sec_proc);
      --ins_debug('err_totales','fin');
      IF cantidad_archivos(numbanco, sec_proc) = 4 THEN
         ins_debug('err_discod', '');
         dbms_application_info.set_action('err_discod');
         err_discod(numlineas, numbanco, periodo, sec_proc);
         -- mensaje(numbanco,'ValidaciÛn: err_discod ',sec_proc);
      END IF;

      --Se cuenta la cantidad de errores encontrados para la entidad actual

      SELECT COUNT(*) INTO inum FROM t_errores;
      -- where cdent=numbanco;

      IF inum = 0 THEN
         --si no se encontraron errores
         UPDATE entidades
            SET pathroot = 'APROBADAS',
                estado   = 3
          WHERE cdentid = numbanco;
         -- mensaje(numbanco,'ValidaciÛn: Entidad Aprobada en ' || to_char(sysdate,'DD/MM/YYYY HH24:MM'),sec_proc);

      ELSE
         SELECT COUNT(*) INTO numb2 FROM t_errores WHERE iderror = 5; --and cdent=numbanco;
         IF (inum - numb2) = 0 THEN
            UPDATE entidades
               SET pathroot = 'REPROBADA (VERIFICAR NOMBRES-REMITIR DOC. RESPALDATORIOS)',
                   estado   = 2
             WHERE cdentid = numbanco;
            -- mensaje(numbanco,'ValidaciÛn: Entidad Aprobada con restricciones en ' || to_char(sysdate,'DD/MM/YYYY HH24:MM'),sec_proc);
         ELSE
            UPDATE entidades
               SET pathroot = 'REPROBADAS ' || '(' || inum || ' errores)',
                   estado   = 2
             WHERE cdentid = numbanco;
            mensaje(numbanco,
                    'ValidaciÛn: Entidad Reprobada en ' || to_char(SYSDATE, 'DD/MM/YYYY HH24:MM'),
                    sec_proc);
         END IF;

      END IF;

      /********************************************************************************/
      COMMIT;

      fechaini := fechain;
      mensaje(numbanco, 'ValidaciÛn concluÌda', sec_proc);
   EXCEPTION
      WHEN OTHERS THEN
         mensaje(numbanco, 'Error en el proceso Validacion ' || SQLERRM, sec_proc);
   END validacion;

   /*******************************************************
        Limpia las tablas para carga de nueva entidad
   *******************************************************/
   PROCEDURE initablas(numbanco VARCHAR2) IS
   BEGIN
      WHILE TRUE LOOP
         DELETE FROM archivos
          WHERE cdent = numbanco
            AND rownum < 100;
         IF SQL%ROWCOUNT <= 0 THEN
            EXIT;
         END IF;
         COMMIT;
      END LOOP;

      EXECUTE IMMEDIATE 'truncate table raw_diska';
      EXECUTE IMMEDIATE 'truncate table raw_diskb';
      EXECUTE IMMEDIATE 'truncate table raw_diskc';
      EXECUTE IMMEDIATE 'truncate table raw_diskd';

      EXECUTE IMMEDIATE 'truncate table t_diska';
      EXECUTE IMMEDIATE 'truncate table t_diskb';
      EXECUTE IMMEDIATE 'truncate table t_diskc';
      EXECUTE IMMEDIATE 'truncate table t_diskd';
      UPDATE parametros SET cdentid = numbanco WHERE nminforme = 'CRC';
      COMMIT;

   END initablas;
   /***************************************************
   Pasa de los RAW_DISKx a la tabla Archivos
   ***************************************************/
   PROCEDURE raw_to_archivos
   (
      p_cdent   IN VARCHAR2,
      p_archivo IN VARCHAR2
   ) IS

      CURSOR ca_cur IS
         SELECT 'CA' archivo, REPLACE(registro, '•', '—') registro,
                decode(bcp4.isnumeric(substr(registro, 1, 2), 0), 1,
                        substr(registro, length(registro) - 5, 6), 0) nroreg, p_cdent
           FROM raw_diska;

      CURSOR cb_cur IS
         SELECT 'CB' archivo, REPLACE(registro, '•', '—') registro,
                decode(bcp4.isnumeric(substr(registro, 1, 2), 0), 1,
                        substr(registro, length(registro) - 5, 6), 0) nroreg, p_cdent
           FROM raw_diskb;

      CURSOR cc_cur IS
         SELECT 'CC' archivo, REPLACE(registro, '•', '—') registro,
                decode(bcp4.isnumeric(substr(registro, 1, 2), 0), 1,
                        substr(registro, length(registro) - 5, 6), 0) nroreg, p_cdent
           FROM raw_diskc;

      CURSOR cd_cur IS
         SELECT 'CD' archivo, REPLACE(registro, '•', '—') registro,
                decode(bcp4.isnumeric(substr(registro, 1, 2), 0), 1,
                        substr(registro, length(registro) - 5, 6), 0) nroreg, p_cdent
           FROM raw_diskd;

      v_count_commit NUMBER(5) := 0;
      v_lugar        VARCHAR2(200);

   BEGIN

      v_lugar := 'Delete Archivos-';
      WHILE TRUE LOOP
         DELETE FROM archivos
          WHERE cdent = p_cdent
            AND archivo = p_archivo
            AND rownum < 500;
         IF SQL%ROWCOUNT <= 0 THEN
            EXIT;
         END IF;
         COMMIT;
      END LOOP;

      IF p_archivo = 'CA' THEN
         v_lugar := 'CA-';
         FOR r IN ca_cur LOOP
            v_count_commit := v_count_commit + 1;
            v_lugar        := 'CA-' || r.nroreg || '-';
            INSERT INTO archivos(Archivo,Registro,Numreg,Cdent) VALUES (r.archivo, r.registro, r.nroreg, r.p_cdent);
            IF v_count_commit >= 500 THEN
               v_count_commit := 0;
               COMMIT;
            END IF;
         END LOOP;
         COMMIT;

      ELSIF p_archivo = 'CB' THEN
         v_lugar := 'CB-';
         FOR r IN cb_cur LOOP
            v_lugar        := 'CB-' || r.nroreg || '-';
            v_count_commit := v_count_commit + 1;
            INSERT INTO archivos(archivo,registro,numreg,cdent) VALUES (r.archivo, r.registro, r.nroreg, r.p_cdent);
            IF v_count_commit >= 500 THEN
               v_count_commit := 0;
               COMMIT;
            END IF;
         END LOOP;
         COMMIT;

      ELSIF p_archivo = 'CC' THEN
         v_lugar := 'CC-';
         FOR r IN cc_cur LOOP
            v_lugar        := 'CC-' || r.nroreg || '-';
            v_count_commit := v_count_commit + 1;
            INSERT INTO archivos (archivo,registro,numreg,cdent) VALUES (r.archivo, r.registro, r.nroreg, r.p_cdent);
            IF v_count_commit >= 500 THEN
               v_count_commit := 0;
               COMMIT;
            END IF;
         END LOOP;
         COMMIT;

      ELSIF p_archivo = 'CD' THEN
         v_lugar := 'CD-';
         FOR r IN cd_cur LOOP
            v_lugar        := 'CD-' || r.nroreg || '-';
            v_count_commit := v_count_commit + 1;
            INSERT INTO archivos(archivo,registro,numreg,cdent)  VALUES (r.archivo, r.registro, r.nroreg, r.p_cdent);
            IF v_count_commit >= 500 THEN
               v_count_commit := 0;
               COMMIT;
            END IF;
         END LOOP;
         COMMIT;

      END IF;

   EXCEPTION
      WHEN OTHERS THEN
         v_lugar := v_lugar || substr(SQLERRM, 1, 170);
         INSERT INTO t_errores
            (iderror, modulo, fuente, mensaje, informado, calculado)
         VALUES
            (0, 'CRC', p_archivo, 'Error en:' || v_lugar, 0, 0);
         COMMIT;
         raise_application_error(-20001, v_lugar);
   END raw_to_archivos;

END bcp4;
/

