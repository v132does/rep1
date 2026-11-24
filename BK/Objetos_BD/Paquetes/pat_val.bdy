CREATE OR REPLACE PACKAGE BODY IT.pat_val IS

   -- Reemplaza los caracteres inválidos de una cadena
   FUNCTION fu_eli_acentos
   (
      p_cadena VARCHAR2,
      p_correo VARCHAR2 DEFAULT 'N'
   ) RETURN VARCHAR2 IS
      v_cadena VARCHAR2(4000);
   BEGIN
      IF p_cadena IS NOT NULL THEN
         v_cadena := translate(p_cadena,
                  'áéíóúàèìòùäëïöüÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`¿[]:;><Çç%',
                  'aeiouaeiouaeiouAEIOUYAEIOUAEIOU     ooa                           Nn ');
         IF nvl(p_correo, 'N') = 'S' THEN
            v_cadena := translate(v_cadena,
                  'âêîôûÂÊÎÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿAa\¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾¿',
                  'aeiouAEIOUAaDO     a  o  y yAa                         ');
         ELSE
            v_cadena := translate(v_cadena,
                  'âêîôûÂÊÎÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿAa\¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾¿_-',
                  'aeiouAEIOUAaDO     a  o  y yAa                           ');
         END IF;
         v_cadena := translate(v_cadena,
                  '''',
                  '  ');
         IF nvl(p_correo, 'N') = 'N' THEN
            v_cadena := translate(v_cadena, '@', ' ');
         END IF;
      END IF;
      RETURN(v_cadena);
   END;

   -- Verifica formatos del correo
   FUNCTION fu_val_correo(p_mail VARCHAR2, p_cod_persona ba_personas.cod_persona%type default null) RETURN VARCHAR2 IS
      v_mail         VARCHAR2(319) := lower(p_mail);
      v_nom_usuario  VARCHAR2(64);
      v_nom_dominio  VARCHAR2(254);
      v_caracter     VARCHAR2(1);
      v_posicion     NUMBER(3);
      v_car_invalido NUMBER(3);
      v_con_caracter NUMBER(3) := 0;
      --
      v_pos_coma     NUMBER(3);
      v_pos_punto    NUMBER(3);
      
      v_espacio VARCHAR2(10);--RE DE-1272 y DE-1273 22/07/2015
      --
      v_correcto varchar2(1) := 'S'; -- DYDMR-4341 -- variable para utlizar en la verficacion de mail
      
------- FUNCION LOCAL PARA VERIFICAR EL DOMINIO RE-DYDMR-2439 - 13/10/2015
      FUNCTION FL_VAL_DOMINIO (P_DOMINIO VARCHAR2) RETURN NUMBER IS
        V_UN_DOMINIO VARCHAR2(50);
        V_POS_INI NUMBER(1) := 1;
        V_POS_FIN NUMBER(2);
        V_NEW_CADENA ge_par_dinamicos.val_parametro%TYPE;
        V_EXISTE NUMBER(3) :=0;
        V_ERROR EXCEPTION;  

      BEGIN
          --LOS DOMINIOS QUE ESTAN ACTIVOS, VAN SEPARADOS POR COMAS EJ: .es,.com,.edu,...etc
           V_NEW_CADENA := trim(lower (FUG_OBT_PARDINAMICO('COD_DOMINIO')));
          IF V_NEW_CADENA IS NULL THEN
            RAISE V_ERROR;    
          END IF;
          
          LOOP 
            V_POS_FIN := INSTR (V_NEW_CADENA,',');
            IF V_POS_FIN = 0 THEN
              V_UN_DOMINIO := trim(SUBSTR(V_NEW_CADENA,V_POS_INI));
            ELSE
               V_UN_DOMINIO := trim(SUBSTR(V_NEW_CADENA,V_POS_INI,V_POS_FIN-1));
               V_NEW_CADENA := SUBSTR(V_NEW_CADENA,V_POS_FIN+1);
            END IF;
            
            --verifica si existe el dominio
            V_EXISTE := nvl(INSTR(lower(P_DOMINIO),V_UN_DOMINIO),0);
           
            EXIT WHEN  V_EXISTE > 0 OR V_POS_FIN = 0;
          end LOOP;

          RETURN V_EXISTE;
      EXCEPTION
        WHEN V_ERROR THEN
          RAISE_APPLICATION_ERROR(-20005, 'No se encuentran los dominios configurados en el parámetro dinámico COD_DOMINIO');
        WHEN OTHERS THEN
          V_EXISTE := 0;
          RETURN V_EXISTE;
      END;
----------------------------------------------------------
   BEGIN
      --- Identificar el primer correo
      v_car_invalido := instr(translate(v_mail,' áéíóúàèìòùäëïöüÁÉÍÓÚÝÄËÏÖÜÀÈÌÒÙ,+´~|°ºª¬!"#$%&/()=?¡¿*¨{}^`¿[]:;><Çç%âêîôûÂÊÎÔÛÃãÐÕ×ØÝÞßåæðõø÷ýþÿ\¢£¤¥¦§©«®¯±²³µ¶·¸¹º»¼½¾¿',
                        '***************************************************************************************************************************'),'*');
      v_pos_punto    := instr(v_mail, ';'); -- hasta el punto y coma
      v_pos_coma     := instr(v_mail, ','); -- hasta la coma
        IF nvl(v_car_invalido,0) = 0 THEN
            IF v_pos_punto = 0 and v_pos_coma = 0 THEN
               v_posicion := length(v_mail);
            ELSIF v_pos_coma = 0 THEN
               v_posicion := v_pos_punto - 1;
            ELSIF v_pos_punto = 0 THEN
               v_posicion := v_pos_coma - 1;
            ELSIF v_pos_coma > v_pos_punto THEN
               v_posicion := v_pos_punto - 1;
            ELSIF v_pos_punto > v_pos_coma THEN
               v_posicion := v_pos_coma - 1;
            ELSE -- Contiene solo 1 correo
               v_posicion := length(v_mail);
            END IF;
            v_mail := substr(v_mail, 1, v_posicion);
            --
            v_posicion    := instr(v_mail, '@');
            v_nom_usuario := substr(v_mail, 1, instr(v_mail, '@') - 1);
            v_nom_dominio := substr(v_mail, instr(v_mail, '@') + 1);
            ---
             
        
            /*
            || Dominios Genéricos
            || ==================
            || .com .net .org
            || .mil .gov .edu .int .coop
            || .info .biz
            || .mobi .es .de
            */
          /*IF instr(v_nom_dominio,'.com',1) > 0 OR
               instr(v_nom_dominio,'.net',1) > 0 OR
               instr(v_nom_dominio,'.org',1) > 0 OR
               instr(v_nom_dominio,'.mil',1) > 0 OR
               instr(v_nom_dominio,'.gov',1) > 0 OR
               instr(v_nom_dominio,'.edu',1) > 0 OR
               instr(v_nom_dominio,'.int',1) > 0 OR
               instr(v_nom_dominio,'.biz',1) > 0 OR
               instr(v_nom_dominio,'.coop',1) > 0 OR
               instr(v_nom_dominio,'.info',1) > 0 OR
               instr(v_nom_dominio,'.mobi',1) > 0 OR
               instr(v_nom_dominio,'.es',1) > 0 THEN --RE DE-1272 y DE-1273 22/07/2015 SE AGREGÓ ".es"
               null;
             ELSE*/
            IF FL_VAL_DOMINIO(v_nom_dominio) = 0 THEN -- se utiliza la funcion local RE-DYDMR-2439 - 13/10/2015
              raise_application_error(-20002, 'Dominio no corresponde a uno Genérico. Cliente: '||p_cod_persona||' Correo: '||v_mail);
            END IF;
            v_mail := pat_val.fu_eli_acentos(v_mail, 'S');
            ---
            FOR i IN 1 .. length(v_mail) LOOP
               v_caracter := substr(v_mail, i, 1);
               IF v_caracter = '@' THEN
                  v_con_caracter := v_con_caracter + 1;
               END IF;
            END LOOP;
            ---   
            IF v_posicion <= 1 OR
               v_posicion = length(v_mail) OR
               v_con_caracter > 1 THEN
               raise_application_error(-20001,
                                       'Direccion de Correo debe tener un único @' ||
                                        ' que no este al principio ni al final. ' ||
                                        'Verifique que se ingresó una sola dirección. Cliente: '||p_cod_persona);
            ELSIF substr(v_nom_usuario, 1, 1) = '.' OR
                  substr(v_nom_usuario, length(v_nom_usuario), 1) = '.' THEN
               raise_application_error(-20002, 'Usuario No puede empezar ni terminar con un punto. Cliente: '||p_cod_persona);
            ELSIF substr(v_nom_dominio, 1, 1) = '.' OR
                  substr(v_nom_dominio, length(v_nom_dominio), 1) = '.' OR
                  instr(v_nom_dominio, '.') = 0 THEN
               raise_application_error(-20003,
                                       'Dominio debe tener al menos' ||
                                        ' un punto que No este al principio ni al final. Cliente: '||p_cod_persona);
            /*ELSIF v_car_invalido > 0 THEN --RE DE-1272 y DE-1273 22/07/2015 SE COMENTA PARA VALIDAR AL INICIO
               raise_application_error(-20004, 'Carater inválido: ' || substr(v_mail, v_car_invalido, 1));*/
            ELSIF instr(v_mail, '..') > 0 THEN
               raise_application_error(-20005, 'No puede ingresar punto consecutivamente. Cliente: '||p_cod_persona);
            ELSIF length(v_nom_usuario) > 64 THEN
               raise_application_error(-20006, 'El nombre de usuario no puede ser mayor a 64 caracteres. Cliente: '||p_cod_persona);
            ELSIF length(v_nom_dominio) > 255 THEN
               raise_application_error(-20007, 'El dominio no puede ser mayor a 255 caracteres. Cliente: '||p_cod_persona);
            END IF;
       ELSE
            SELECT decode(substr(v_mail,v_car_invalido,1),' ','"espacio"',substr(v_mail,v_car_invalido,1))
              INTO v_espacio
              FROM dual;
               raise_application_error(-20004, 'Carater inválido: ' || v_espacio||' - Cliente: '||p_cod_persona);
        END IF;
        --- DYDMR-4341 - SE VALIDA QUE SOLO SEAN CARACTERES PERMITIDOS [A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$')
            v_correcto := paw_bel.lf_val_mail(v_mail);
            if v_correcto = 'N' then
               if p_cod_persona is not null then
                  raise_application_error(-20008, 'Carater inválido, verificar el Mail del Cliente: '||p_cod_persona);
               else
                 raise_application_error(-20009, 'Carater inválido, verificar el Mail del Cliente');
               end if; 
           end if;
        ---
       
      RETURN v_mail;
   END;

   -- Actualiza en forma dinámica campos definidos en el dominio TAR_ACT_ACENTOS
   PROCEDURE pr_act_acentos(p_dominio ba_cod_referencias.dominio%TYPE,
                            p_cod_persona ba_personas.cod_persona%type default null) IS
      v_sentencia VARCHAR2(4000);
      v_error     VARCHAR2(4000);
      CURSOR c_campos IS
         SELECT a.val_maximo, a.abreviatura
           FROM ba_cod_referencias a
          WHERE a.dominio = p_dominio
          ORDER BY to_number(a.val_minimo);
   BEGIN
      FOR i IN c_campos LOOP
         v_sentencia := 'update ' || i.abreviatura || chr(10) || '   set ' || i.val_maximo ||
                        ' = pat_val.fu_eli_acentos(' || i.val_maximo || ')';
         if p_cod_persona is not null then
            v_sentencia := v_sentencia || ' where cod_persona = ' || p_cod_persona;
         end if;
         sql_util.ejecute_dml(v_sentencia, v_error);
         IF v_error IS NOT NULL THEN
            raise_application_error(-20000,
                                    'Error act.' || i.abreviatura || '.' || i.val_maximo || ':' ||
                                     v_error);
         END IF;
      END LOOP;
   END;
END pat_val;
/

