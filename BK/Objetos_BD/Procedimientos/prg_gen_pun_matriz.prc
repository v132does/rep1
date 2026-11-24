CREATE OR REPLACE PROCEDURE IT.PRG_GEN_PUN_MATRIZ
 IS
 v_cod_puntaje cr_puntajes.cod_puntaje%type;
BEGIN
   --llamar al proceso de puntuación, para procesos independientes
   prg_gen_puntuacion(null, null, v_cod_puntaje);
END;
/

