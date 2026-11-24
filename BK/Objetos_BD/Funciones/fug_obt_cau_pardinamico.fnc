CREATE OR REPLACE FUNCTION IT.fug_obt_cau_pardinamico
(
   p_tipo         ge_causales.tipo%TYPE,
   p_par_causal   ge_par_causales.parametro%TYPE,
   p_par_dinamico ge_par_dinamicos.parametro%TYPE
) RETURN NUMBER IS
   v_cod_causa    ge_causales.cod_causa%TYPE;
   v_par_dinamico ge_par_dinamicos.parametro%TYPE;
   CURSOR c_causales IS
      SELECT m.cod_causa
        FROM ge_causales m, ge_par_causales c
       WHERE m.cod_causa = c.cod_causa
         AND m.tipo = p_tipo
         AND c.parametro = p_par_causal;
BEGIN
   FOR rg_causales IN c_causales LOOP
      v_par_dinamico := fug_obt_pardinamico(p_par_dinamico);
      IF instr(',' || v_par_dinamico || ',', ',' || rg_causales.cod_causa || ',') > 0 THEN
         v_cod_causa := rg_causales.cod_causa;
         RETURN v_cod_causa;
      END IF;
   END LOOP;
   RETURN v_cod_causa;

END fug_obt_cau_pardinamico;
/

