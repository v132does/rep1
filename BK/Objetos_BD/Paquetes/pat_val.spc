CREATE OR REPLACE PACKAGE IT.PAT_VAL IS

   -- Author  : XPY0038
   -- Created : 23/12/2013 10:59:09 a.m.
   -- Purpose : Validaciones de datos de los campos del módulo de Tarjetas

   -- Reemplaza los caracteres inválidos de una cadena
      G_PROCESO      VARCHAR2(40);
   FUNCTION fu_eli_acentos
   (
      p_cadena VARCHAR2,
      p_correo VARCHAR2 DEFAULT 'N'
   ) RETURN VARCHAR2;

   -- Verifica formatos del correo
   FUNCTION fu_val_correo(p_mail VARCHAR2, p_cod_persona ba_personas.cod_persona%type default null) RETURN VARCHAR2;

   -- Actualiza en forma dinámica campos definidos en el dominio TAR_ACT_ACENTOS
   PROCEDURE pr_act_acentos(p_dominio ba_cod_referencias.dominio%TYPE,
                            p_cod_persona ba_personas.cod_persona%type default null);

END pat_val;
/

