import { bnTransform } from "@/utils/bnTransform";
import { useController, useFormContext } from "react-hook-form";
import { formatUnits } from "viem";

export const BNInput = (props: {
  name: string;
  placeholder?: string;
  className?: string;
  disabled?: boolean;
  decimals?: number;
}) => {
  const { control } = useFormContext();
  const { field } = useController({ name: props.name, control });

  return (
    <input
      {...props}
      value={formatUnits(field.value, props.decimals || 18)}
      name={field.name}
      onChange={(e) =>
        field.onChange(bnTransform.toBn(e.target.value, props.decimals || 18))
      }
    />
  );
};
